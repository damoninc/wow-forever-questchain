#!/usr/bin/env bash
set -euo pipefail

ref_type=${1:?Expected Git ref type}
ref_name=${2:?Expected Git ref name}
toc=ForeverQuestChain/ForeverQuestChain.toc
version=$(awk '/^## Version:/ {print $3; exit}' "$toc")
number='(0|[1-9][0-9]*)'
if [[ ! "$version" =~ ^$number\.$number\.$number(-beta\.$number)?$ ]]; then
  echo "Invalid TOC version: $version. Use major.minor.patch or major.minor.patch-beta.N." >&2
  exit 1
fi
if [[ "$ref_type" == tag && "$ref_name" != "v$version" ]]; then
  echo "The Git tag must match the addon TOC version (v$version)." >&2
  exit 1
fi

# Keep a readable development version in source; let BigWigs identify the
# packaged build consistently in its TOC, archive, and addon-manager metadata.
sed -i 's/^## Version:.*/## Version: @project-version@/' "$toc"
