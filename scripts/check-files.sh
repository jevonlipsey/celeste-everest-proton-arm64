#!/usr/bin/env bash

# prints size and hash for the mono/cecil set in a celeste install, so it can be
# compared against handheld/provenance.md. the point is to catch a set that was
# assembled from more than one build: matching version numbers do not mean
# matching files, and that mismatch is what breaks mono at first launch.

set -euo pipefail

game="${1:-}"
if [ -z "$game" ]; then
    echo "usage: check-files.sh /path/to/Celeste"
    exit 2
fi

if [ ! -f "$game/Celeste.exe" ] && [ ! -f "$game/Celeste.dll" ]; then
    echo "no Celeste.exe or Celeste.dll in $game - point this at the game folder"
    exit 2
fi

KNOWN_MONOMOD='4cc92af374e5c3af63e76f2e31647f6ad2baf49a8a5446ea17a193482969ffc4'
KNOWN_CECIL_PDB='30e233b32625d933520a2df22c41be2822d0530a849b9dfb4c67dbc01b7b2b48'

FILES=(
    MonoMod.exe
    MonoMod.Utils.dll
    MonoMod.RuntimeDetour.dll
    MonoMod.Core.dll
    MonoMod.Patcher.dll
    Mono.Cecil.dll
    Mono.Cecil.Pdb.dll
)

printf '%-28s %10s  %-16s  %s\n' FILE SIZE SHA256 NOTE

for f in "${FILES[@]}"; do
    if [ ! -f "$game/$f" ]; then
        printf '%-28s %10s  %-16s  %s\n' "$f" - - 'MISSING'
        continue
    fi

    size=$(wc -c < "$game/$f" | tr -d ' ')
    hash=$(shasum -a 256 "$game/$f" 2>/dev/null | cut -d' ' -f1)

    note=''
    case "$f" in
        MonoMod.exe)
            [ "$hash" = "$KNOWN_MONOMOD" ] && note='matches the known-good pair' || note='differs from the known-good pair'
            ;;
        Mono.Cecil.Pdb.dll)
            if [ "$hash" = "$KNOWN_CECIL_PDB" ]; then
                note='matches the known-good pair'
            else
                note='differs - see the 89600-byte trap in PROVENANCE.md'
            fi
            ;;
    esac

    printf '%-28s %10s  %-16s  %s\n' "$f" "$size" "${hash:0:16}" "$note"
done

echo
echo 'known-good MonoMod.exe      4cc92af374e5c3af (67584 bytes)'
echo 'known-good Mono.Cecil.Pdb   30e233b32625d933 (88064 bytes)'
echo 'macOS 4449 Cecil.Pdb        447ede1984bb.... (89600 bytes)  <- same version, does not work for us'
