#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/zigtools/zls"
TOOL_NAME="zls"
TOOL_TEST="zls --version"
ZIGTOOLS_URL="https://builds.zigtools.org"

fail() {
	echo -e "asdf-$TOOL_NAME: $*"
	exit 1
}

curl_opts=(-fsSL)

# NOTE: You might want to remove this if zls is not hosted on GitHub releases.
if [ -n "${GITHUB_API_TOKEN:-}" ]; then
	curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
	git ls-remote --tags --refs "$GH_REPO" |
		grep -o 'refs/tags/.*' | cut -d/ -f3- |
		sed 's/^v//' # NOTE: You might want to adapt this sed to remove non-version strings from tags
}

list_all_versions() {
	list_github_tags | grep -v '0.1.0' | grep -v '0.2.0'
	# v0.1.0 & v0.2.0 are not available on https://builds.zigtools.org/
}

get_platform() {
	local platform=""

	platform="$(uname | tr '[:upper:]' '[:lower:]')"
	case "$platform" in
	darwin) platform="macos" ;;
	esac

	echo -n "$platform"
}

get_arch() {
	local arch=""

	case "$(uname -m)" in
	x86_64 | amd64) arch="x86_64" ;;
	i686 | i386) arch="x86" ;;
	aarch64 | arm64) arch="aarch64" ;;
	*)
		echo "Arch '$(uname -m)' not supported!" >&2
		exit 1
		;;
	esac

	echo -n $arch
}

get_extname() {
	local extname=tar.xz

	echo -n "$extname"
}

download_release() {
	local version filename url
	version="$1"
	filename="$2"
	platform="$(get_platform)"
	arch="$(get_arch)"
	extname="$(get_extname)"

	url="$ZIGTOOLS_URL/zls-${platform}-${arch}-${version}.${extname}"

	echo "* Downloading $TOOL_NAME release $version..."
	curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
	local install_type="$1"
	local version="$2"
	local install_path="${3%/bin}"

	if [ "$install_type" != "version" ]; then
		fail "asdf-$TOOL_NAME supports release installs only"
	fi

	(
		mkdir -p "$install_path/bin"

		local tool_cmd
		tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
		cp "$ASDF_DOWNLOAD_PATH/$tool_cmd" "$install_path/bin"
		chmod +x "$install_path/bin/$tool_cmd"
		test -x "$install_path/bin/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

		echo "$TOOL_NAME $version installation was successful!"
	) || (
		rm -rf "$install_path"
		fail "An error occurred while installing $TOOL_NAME $version."
	)
}
