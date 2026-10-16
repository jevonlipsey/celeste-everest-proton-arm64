#!/usr/bin/env bash

# builds dist/mono-patches.zip, the release asset people download.
#
# the zip unpacks into a single folder holding the two files and INSTALL.txt,
# so nothing lands loose in anyone's game directory.

set -euo pipefail
cd "$(dirname "$0")/.."

rm -rf dist/mono-patches
mkdir -p dist/mono-patches

cp handheld/Mono.Cecil.Pdb.dll handheld/MonoMod.exe handheld/INSTALL.txt dist/mono-patches/

# so the download can be checked against the readme
( cd dist/mono-patches && shasum -a 256 Mono.Cecil.Pdb.dll MonoMod.exe > SHA256SUMS )

rm -f dist/mono-patches.zip
( cd dist && zip -q -r mono-patches.zip mono-patches )

echo
echo 'packaged dist/mono-patches.zip'
unzip -l dist/mono-patches.zip
