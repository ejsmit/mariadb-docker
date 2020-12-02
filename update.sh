#!/usr/bin/env bash
set -Eeuo pipefail

defaultSuite='3.11'
declare -A suites=(
	[10.4]='3.11'
	[10.3]='3.9'
	[10.2]='3.8'
	[10.1]='3.7'
)
declare -A dpkgArchToBashbrew=(
	[amd64]='amd64'
	[armel]='arm32v5'
	[armhf]='arm32v7'
	[arm64]='arm64v8'
	[i386]='i386'
	[ppc64el]='ppc64le'
	[s390x]='s390x'
)

getRemoteVersion() {
	local version="$1"; shift # 10.3
	local suite="$1"; shift # bionic
	local dpkgArch="$1"; shift # arm64

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
	if [ "$version" == "root" ]; then
		continue
	fi
	suite="${suites[$version]:-$defaultSuite}"
	fullVersion="$(getRemoteVersion "$version" "$suite" 'x86_64')"
	if [ -z "$fullVersion" ]; then
		echo >&2 "warning: cannot find $version in $suite"
		continue
	fi

	mariaVersion="${fullVersion%-r*}"
	mariaVersion="${mariaVersion##*-}"
	# "Alpha", "Beta", "Gamma", "RC", "Stable", etc.
	releaseStatus='I hope it is Stable'
	# releaseStatus="$(
	# 	wget -qO- 'https://downloads.mariadb.org/mariadb/+releases/' \
	# 		| xargs -d '\n' \
	# 		| grep -oP '<tr>.+?</tr>' \
	# 		| grep -P '>\Q'"$mariaVersion"'\E<' \
	# 		| grep -oP '<td>[^0-9][^<]*</td>' \
	# 		| sed -r 's!^.*<td>([^0-9][^<]*)</td>.*$!\1!'
	# )"
	# case "$releaseStatus" in
	# 	Alpha | Beta | Gamma | RC | Stable ) ;; # sanity check
	# 	*) echo >&2 "error: unexpected 'release status' value for $mariaVersion: $releaseStatus"; exit 1 ;;
	# esac

	echo "$version: $mariaVersion ($releaseStatus)"

	arches=""
	# sortedArches="$(echo "${!dpkgArchToBashbrew[@]}" | xargs -n1 | sort | xargs)"
	# for arch in $sortedArches; do
	# 	if ver="$(getRemoteVersion "$version" "$suite" "$arch")" && [ -n "$ver" ]; then
	# 		arches="$arches ${dpkgArchToBashbrew[$arch]}"
	# 	fi
	# done

	cp Dockerfile.template "$version/Dockerfile"

	backup='mariadb-backup'
	if [[ "$version" == "10.1" ]]; then
		# mariabackup only appeared in 10.2 and later.  Use mysqldump in 10.1
		backup=""
	fi

	cp docker-entrypoint.sh "$version/"
	sed -i \
		-e 's!%%MARIADB_VERSION%%!'"$fullVersion"'!g' \
		-e 's!%%MARIADB_MAJOR%%!'"$version"'!g' \
		-e 's!%%MARIADB_RELEASE_STATUS%%!'"$releaseStatus"'!g' \
		-e 's!%%SUITE%%!'"$suite"'!g' \
		-e 's!%%BACKUP_PACKAGE%%!'"$backup"'!g' \
		-e 's!%%ARCHES%%!'"$arches"'!g' \
		"$version/Dockerfile"

	case "$version" in
		10.1 | 10.2 | 10.3 | 10.4) ;;
		*) sed -i '/backwards compat/d' "$version/Dockerfile" ;;
	esac
done
