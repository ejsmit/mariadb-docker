#!/usr/bin/env bash
set -Eeuo pipefail

defaultSuite='3.12'
declare -A suites=(
	[10.4]='3.12'
	[10.3]='3.10'
	[10.2]='3.8'
)
declare -A dpkgArchToBashbrew=(
	[x86_64]='x86_64'
	[armhf]='armhf'
	[aarch64]='aarch64'
)

getRemoteVersion() {
	local version="$1"; shift 
	local suite="$1"; shift 
	local dpkgArch="$1"; shift

	echo "$(
		curl -fsSL "http://dl-cdn.alpinelinux.org/alpine/v$suite/main/$dpkgArch/" 2>/dev/null  \
			| grep mariadb-$version \
			| awk -F '"' '{ print $2 }'
	)"
}

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
fi
versions=( "${versions[@]%/}" )

for version in "${versions[@]}"; do

	suite="${suites[$version]:-$defaultSuite}"
	fullVersion="$(getRemoteVersion "$version" "$suite" 'x86_64')"
	if [ -z "$fullVersion" ]; then
		echo >&2 "warning: cannot find $version in $suite"
		continue
	fi

	mariaVersion="${fullVersion%.apk}"
	mariaVersion="${mariaVersion#*-}"

	releaseStatus='Stable'

	echo "$version: $mariaVersion ($releaseStatus)"

	arches=""
	sortedArches="$(echo "${!dpkgArchToBashbrew[@]}" | xargs -n1 | sort | xargs)"
	for arch in $sortedArches; do
		if ver="$(getRemoteVersion "$version" "$suite" "$arch")" && [ -n "$ver" ]; then
			arches="$arches ${dpkgArchToBashbrew[$arch]}"
		fi
	done

	cp Dockerfile.template "$version/Dockerfile"

	backup='mariadb-backup'

	cp docker-entrypoint.sh "$version/"
	sed -i \
		-e 's!%%MARIADB_VERSION%%!'"$mariaVersion"'!g' \
		-e 's!%%MARIADB_MAJOR%%!'"$version"'!g' \
		-e 's!%%MARIADB_RELEASE_STATUS%%!'"$releaseStatus"'!g' \
		-e 's!%%SUITE%%!'"$suite"'!g' \
		-e 's!%%BACKUP_PACKAGE%%!'"$backup"'!g' \
		-e 's!%%ARCHES%%!'"$arches"'!g' \
		"$version/Dockerfile"

	case "$version" in
		10.2 | 10.3 | 10.4) ;;
		*) sed -i '/backwards compat/d' "$version/Dockerfile" ;;
	esac
done




