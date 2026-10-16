# celeste-everest-proton-arm64

Getting **Everest** to run on an ARM64 Android handheld (Steam + Proton + FEX translation + Wine-Mono).

Celeste itself is fine on this stack — the game boots, renders and plays. What fails is Everest's first-run patch step, because patching the game writes an assembly *with debug symbols*, and Cecil's native PDB writer reaches for Windows DIA/COM libraries that Wine does not provide. The fix is small and surgical: a `Mono.Cecil.Pdb.dll` whose native PDB **writer** entry points return `null`, so the patched assembly is written without symbols.

Verified on a Retroid Pocket Nova through DroidDeck and a DroidDeck-class handheld: Celeste `1.4.0.0-fna`, Everest `4449-azure-ddba3`.

Not affiliated with Everest, MonoMod, Mono.Cecil or Celeste.

## The fix

Two files go into the folder holding `Celeste.exe`:

| File | What it is | SHA-256 (first 16) |
| --- | --- | --- |
| [`handheld/Mono.Cecil.Pdb.dll`](handheld/PROVENANCE.md) | Cecil `0.11.4.0`, **rebuilt with the native PDB writer stubbed** | `30e233b32625d933` |
| [`handheld/MonoMod.exe`](handheld/PROVENANCE.md) | MonoMod `22.1.4.3`, unmodified | `4cc92af374e5c3af` |

Back up what you replace. Then launch once and watch `log.txt` next to the executable.

Only the first file is modified. What it changes, precisely:

```text
Mono.Cecil.Pdb.PdbWriterProvider::GetSymbolWriter          ldnull / ret   (both overloads)
Mono.Cecil.Pdb.NativePdbWriterProvider::GetSymbolWriter    ldnull / ret   (both overloads)
Mono.Cecil.Pdb.NativePdbWriterProvider::CreateWriter       ldnull / ret
```

Nothing else. The *reader* side (`PdbReaderProvider`, `NativePdbReaderProvider`, `NativePdbReader`) is byte-for-byte what upstream Cecil has, because reading is opt-in and is not what fails. Pristine `PdbWriterProvider::GetSymbolWriter` checks for portable symbols and otherwise constructs a native writer; that construction is the point where Wine runs out of road.

`scripts/check-files.sh /path/to/Celeste` prints size and hash for the whole set so you can confirm what you have.

### Rebuilding the file yourself

The build we use is in `handheld/`, but if you would rather build it, the edit is in Cecil's own source (`0.11.4.0`, <https://github.com/jbevain/cecil>): make `Mono.Cecil.Pdb.PdbWriterProvider.GetSymbolWriter` and `Mono.Cecil.Pdb.NativePdbWriterProvider.GetSymbolWriter` / `CreateWriter` return `null` instead of constructing a writer. Everything else stays upstream. We do not have the exact tree it was built from, so treat the binary as the artifact of record and the edit above as its meaning.

## Why this is the failure, not the mod

The chain that costs people an evening:

1. Celeste runs under Proton, so .NET is Wine-Mono, not Microsoft's runtime.
2. Everest's first launch patches `Celeste.exe` with MonoMod.
3. MonoMod writes the patched assembly through Cecil, and asks for a symbol writer.
4. Cecil's native PDB writer is a COM interop layer over Windows' DIA / `ISymUnmanaged*` APIs. Wine does not ship those libraries.
5. The write fails during boot. Whether you see a stack, a hang, or nothing at all depends on where the runtime gives up — a Wine-Mono failure can leave the process alive at ~0% CPU, so Steam spins forever and it looks like a slow first launch.

With the writer stubbed, MonoMod is told "no symbol writer" and writes the assembly anyway. Debug symbols are the only casualty, which nobody running Celeste on a handheld cares about.

## Recognising the other, unrelated failures

These are real and we hit all three, but they are *not* solved by the two files above. Read the full stacks in your own logs and match by shape.

### Invalid IL code in a `DMD` wrapper

```text
System.InvalidProgramException: Invalid IL code in [wrapper dynamic-method]
Celeste.ScreenWipe:DMD<Celeste.ScreenWipe::get_Bottom> (Celeste.ScreenWipe): IL_000f: ret

  at MonoMod.RuntimeDetour.Platforms.DetourRuntimeILPlatform.GetFunctionPointer(MethodBase, RuntimeMethodHandle)
  at MonoMod.RuntimeDetour.Detour._TopApply()
  at MonoMod.RuntimeDetour.ILHook..ctor(MethodBase, ILContext+Manipulator, ILHookConfig)
```

Everest installed, a mod is loading, and a hook on a trivial getter produced a wrapper the runtime rejected. It names whichever method the mod hooked first, so the method is a red herring; the useful part is that this is a *runtime hooking* failure, not a boot failure. Well-behaved mods catch it and log a warning rather than dying — see [celeste-43aspect](https://github.com/jevonlipsey/celeste-43aspect) for a mod written that way.

### MissingMethodException while a mod loads

```text
System.MissingMethodException: Method not found: void .<>c..ctor(int,int,Celeste.Mod.LogLevel,string,bool)
  at Celeste.Mod.CelesteFit.CelesteFitModule.Load ()
```

That mod was built against an **Everest-merged `Celeste.dll`**. It compiles clean and dies at load. Build against the pristine game assembly plus `Celeste.Mod.mm.dll` separately.

### Nothing at all

No `[Everest] Booting` line, process at ~0% CPU, Steam waiting. Not slow — dead. Restart Steam rather than waiting, then apply the fix above.

## Deploying files to the handheld

`adb` connects as the unprivileged `shell` user, which cannot write Steam's game folder. Stage in `/sdcard/Download`, then copy into place from a terminal **on the device**:

```bash
adb push handheld/Mono.Cecil.Pdb.dll /sdcard/Download/
```

## Props and traps

- **Keep the whole MonoMod/Cecil set from one build.** Version numbers lie: the macOS and Windows Everest 4449 releases both ship a `Mono.Cecil.Pdb.dll` reporting `0.11.4.0`, and they are different binaries (89600 bytes, hashes `447ede1984bb` / `a5249a04ad8f`) — both pristine, both fail here.
- **Steam "verify integrity" and auto-update will overwrite the patched files and `Celeste.exe`.** Keep auto-update off, or re-apply after.
- **Launch options cannot change the runtime.** `WINEDLLOVERRIDES="mscoree=b" %command%` prepends to what the handheld's Proton config already sets and loses.
- **Celeste needs the FNA branch** (`beta-1.3.3.0` on Steam, or the itch FNA build) for modern Everest at all.
- **Mods must be `net472`.** Wine-Mono cannot load a `net8.0` assembly.

## Open questions

- Whether a *pristine* Everest install ever survives its first patch on this stack without the stubbed Cecil. Every device we set up already needed it, which suggests not, but that is not proof.
- `MonoMod.exe` here is byte-identical to the stock Everest 4449 build, so it is supplied unmodified. If your working install has a different one, that is a data point we would like.

## Related

[**celeste-43aspect**](https://github.com/jevonlipsey/celeste-43aspect) — a 4:3 aspect-ratio mod for PC Celeste that runs on exactly this stack, and where these notes came from.

## If you are stuck

Open an issue with the device, Proton/FEX version, the Celeste + Everest build strings from the top of `log.txt`, and the full stack trace.
