# The two files, and exactly what is different about them

## handheld/Mono.Cecil.Pdb.dll — patched

| | |
| --- | --- |
| Size | 88064 bytes |
| SHA-256 | `30e233b32625d933520a2df22c41be2822d0530a849b9dfb4c67dbc01b7b2b48` |
| Reports | `Mono.Cecil.Pdb` v`0.11.4.0` |
| Origin | taken out of our working install on the handheld; where it was built is unknown |

It is **not** any published build. It matches neither of the pristine Cecil 0.11.4 artifacts from NuGet, and its IL differs from each (`548` lines from `net40`, `1209` from `netstandard2.0`) while its type and method metadata is identical to both. Same version, same surface, different code: a rebuild, not a swap.

### What the rebuild changes

Five method bodies, all on the writer side, all returning `null`:

```text
Mono.Cecil.Pdb.PdbWriterProvider::GetSymbolWriter        -> ldnull / ret   (both overloads)
Mono.Cecil.Pdb.NativePdbWriterProvider::GetSymbolWriter  -> ldnull / ret   (both overloads)
Mono.Cecil.Pdb.NativePdbWriterProvider::CreateWriter     -> ldnull / ret
```

Pristine `net40`, for contrast, checks for portable PDB symbols and otherwise constructs a writer; its stream overload throws `NotImplementedException`. Ours never gets that far.

Nothing on the reader side changed: `PdbReaderProvider`, `NativePdbReaderProvider` and `NativePdbReader` are instruction-for-instruction identical to pristine. Reading is opt-in and is not what fails, so the patch is the minimum that removes the dependency on the native DIA/COM PDB libraries Wine does not ship.

### Why the sizes are not the way to check anything

Three files, all claiming Cecil `0.11.4.0`:

| File | Size | Hash (first 16) | Works here? |
| --- | --- | --- | --- |
| our patched build | 88064 | `30e233b32625d933` | **yes** |
| pristine NuGet `net40` | 89600 | `447ede1984bb4acd` | no |
| pristine NuGet `netstandard2.0` | 89600 | `a5249a04ad8f` | no |

The macOS Everest 4449 release ships the `net40` one, byte-for-byte. Nothing distinguishes the two pristine builds except size and codegen, and nothing distinguishes the patched one from either except the five stubs above. Verify by hash, or by the IL if you want to be certain.

## handheld/MonoMod.exe — unmodified

| | |
| --- | --- |
| Size | 67584 bytes |
| SHA-256 | `4cc92af374e5c3af63e76f2e31647f6ad2baf49a8a5446ea17a193482969ffc4` |
| Reports | `MonoMod` v`22.1.4.3` |
| Origin | byte-identical to the copy in the macOS Everest 4449 release |

Supplied as-is because our install needed it present; Steam's log shows the game loading `MonoMod.exe` from the game folder, so it is part of the working set. We found no modification in it. If your install runs a different one, please open an issue with its hash.

## The rest of the set

`scripts/check-files.sh` covers these. Nothing else on our device is modified, and the versions we run are:

| File | Version |
| --- | --- |
| `MonoMod.exe` | `22.1.4.3` |
| `MonoMod.Utils.dll` | `22.1.4.3` |
| `MonoMod.RuntimeDetour.dll` | `22.1.4.3` |
| `MonoMod.Core.dll` | `1.3.1.0` |
| `MonoMod.Patcher.dll` | `0.0.0.0` |
| `Mono.Cecil.dll` | `0.11.4.0` |
| `Mono.Cecil.Pdb.dll` | `0.11.4.0` — the patched one |

## Verify a set

```bash
../scripts/check-files.sh "/path/to/Celeste"
```

Prints size and SHA-256 for each file and marks the two above as matching or not.

## License

`Mono.Cecil` is © Jb Evain and contributors, MIT, <https://github.com/jbevain/cecil>. `MonoMod` is © the MonoMod contributors, MIT, <https://github.com/MonoMod/MonoMod>. The Cecil build here is modified; the modification is described above and is the whole of the difference. See [`../THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md).
