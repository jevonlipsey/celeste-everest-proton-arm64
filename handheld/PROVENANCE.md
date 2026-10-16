# The pair that works

Two files, dropped into the folder holding `Celeste.exe`. Back up whatever they replace. This is the pair that stopped the `InvalidProgramException … DMD<…>` failure on our units.

## MonoMod.exe

| | |
| --- | --- |
| Size | 67584 bytes |
| SHA-256 | `4cc92af374e5c3af63e76f2e31647f6ad2baf49a8a5446ea17a193482969ffc4` |
| Reports | `MonoMod` v`22.1.4.3` |
| Origin | byte-identical to the copy shipped in the macOS Everest 4449 release |

## Mono.Cecil.Pdb.dll

| | |
| --- | --- |
| Size | 88064 bytes |
| SHA-256 | `30e233b32625d933520a2df22c41be2822d0530a849b9dfb4c67dbc01b7b2b48` |
| Reports | `Mono.Cecil.Pdb` v`0.11.4.0` |
| Origin | taken out of our working Windows install. We do not know which build it originally came from. |

## The other candidate, for contrast

The macOS Everest 4449 release ships a **different** `Mono.Cecil.Pdb.dll`:

| | |
| --- | --- |
| Size | 89600 bytes |
| SHA-256 | `447ede1984bb…` |
| Reports | `Mono.Cecil.Pdb` v`0.11.4.0` — the same version string |

Same version, different file, different behaviour. This is the trap that cost us an afternoon, and it is the reason to verify by hash rather than by version or size guesswork.

## Verify your own install

```bash
../scripts/check-files.sh "/path/to/Celeste"
```

Prints size and SHA-256 for every file in the set, and marks `Mono.Cecil.Pdb.dll` as matching the known-good hash or not.

## License

Both files are redistributed here under their own MIT licenses:

- MonoMod — © the MonoMod contributors, MIT, <https://github.com/MonoMod/MonoMod>
- Mono.Cecil — © Jb Evain, MIT, <https://github.com/jbevain/cecil>

Neither is modified. See [`../THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md).
