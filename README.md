# celeste-everest-proton-arm64

**Everest for Celeste on an ARM64 Android handheld (Retroid Pocket Nova, DroidDeck and friends).**

Celeste itself is fine on Steam + Proton on these devices — it boots, renders and plays. **Everest** is the part that breaks: its first launch patches the game and writes the result *with debug symbols*, and Cecil's native PDB writer is a COM layer over Windows' DIA APIs that Wine does not ship. The patch is small and surgical: a rebuild of `Mono.Cecil.Pdb.dll` whose native PDB **writer** entry points return `null`, so the patched game is written without symbols.

Tested on a Retroid Pocket Nova through DroidDeck and a DroidDeck-class handheld: Celeste `1.4.0.0-fna`, Everest `4449-azure-ddba3`.

Not affiliated with Everest, MonoMod, Mono.Cecil or Celeste.

---

## Install

### 1. Before you start

| You need | Where |
| --- | --- |
| Celeste on Steam, **FNA branch** | Steam → Celeste → Properties → Betas → `beta-1.3.3.0`. The default branch will not run modern Everest at all |
| Everest 1.4.x (tested: **4449**) | <https://everestapi.github.io>, or the Everest repo's releases |
| **[mono-patches.zip](../../releases/latest/download/mono-patches.zip)** | the release asset from this repo |
| A way to copy files into Steam's game folder on the device | a file manager that can reach it, DroidDeck's file tools, or `adb` |

Everest's installer is a Windows/macOS program, so the usual handheld route is: install Everest on a PC, then copy the Celeste folder over. On the handheld you need this patch whenever Everest has to patch the game *on the device* — a fresh setup, or after anything that re-patches (see [traps](#traps)).

### 2. Put the files in the game folder

1. Find the game folder — the one holding `Celeste.exe`. Typical on a handheld:

   ```text
   <steam library>/steamapps/common/Celeste/
   ```

   With a PRoot-based setup that is usually `/root/.local/share/Steam/steamapps/common/Celeste/` (Celeste is app **504230** in Steam's `steamapps`).

2. **Back up** the two files you are about to replace. Copy `Mono.Cecil.Pdb.dll` and `MonoMod.exe` out of the game folder somewhere safe first.

3. Unzip `mono-patches.zip` and copy both files from it into that folder, overwriting what is there.

If you use `adb`, note that it connects as the unprivileged `shell` user and cannot write into Steam's folder. Stage and then copy on the device:

```bash
adb push mono-patches.zip /sdcard/Download/
adb push scripts/check-files.sh /sdcard/Download/   # optional
```

then unzip and copy from `/sdcard/Download` using a terminal **on the device**.

### 3. Launch it

Start Celeste through Steam on the handheld and let Everest finish its patch. You should reach the title screen. The first run takes a while; a run that never gets past a black window is the failure this patch fixes.

To confirm: `log.txt` in the game folder should get an `[Everest] Booting` line, and the Everest version string at the top should read `[Everest: 4449-azure-ddba3]`.

### 4. Add mods

Drop any mod `.zip` into `Mods/` next to `Celeste.exe` and restart. Everest installs it on boot — no "install missing dependencies" step is needed for mods written against the game's own API.

A mod built for this stack: [celeste-43aspect](https://github.com/jevonlipsey/celeste-43aspect) (4:3 aspect ratio).

---

## What is in the patch, exactly

Two files, inside the zip's single `mono-patches/` folder next to `INSTALL.txt` and `SHA256SUMS`:

| File | Size | SHA-256 | Modified? |
| --- | --- | --- | --- |
| `Mono.Cecil.Pdb.dll` | 88064 | `30e233b32625d933520a2df22c41be2822d0530a849b9dfb4c67dbc01b7b2b48` | **yes** — Cecil `0.11.4.0`, native PDB writing removed |
| `MonoMod.exe` | 67584 | `4cc92af374e5c3af63e76f2e31647f6ad2baf49a8a5446ea17a193482969ffc4` | no — stock MonoMod `22.1.4.3` |

`scripts/check-files.sh /path/to/Celeste` prints size and hash for the whole MonoMod/Cecil set and marks these two.

### The modification

Five method bodies, all writer-side, all `ldnull; ret`:

```text
Mono.Cecil.Pdb.PdbWriterProvider::GetSymbolWriter          (both overloads)
Mono.Cecil.Pdb.NativePdbWriterProvider::GetSymbolWriter    (both overloads)
Mono.Cecil.Pdb.NativePdbWriterProvider::CreateWriter
```

Nothing else changes. The reader side — `PdbReaderProvider`, `NativePdbReaderProvider`, `NativePdbReader` — is instruction-for-instruction identical to upstream, because reading is opt-in and is not what fails. Pristine `net40` instead checks for portable PDB symbols and otherwise constructs a native writer, which is exactly where Wine runs out of road. Telling MonoMod "no symbol writer" is enough: the patched assembly is written anyway, minus debug symbols, which nobody playing on a handheld misses.

### Why you cannot check this by version or size

Three different `Mono.Cecil.Pdb.dll` files, all reporting `0.11.4.0`:

| File | Size | SHA-256 (first 16) | Works here? |
| --- | --- | --- | --- |
| this patch | 88064 | `30e233b32625d933` | **yes** |
| pristine NuGet `net40` | 89600 | `447ede1984bb4acd` | no |
| pristine NuGet `netstandard2.0` | 89600 | `a5249a04ad8f` | no |

The macOS Everest 4449 release ships the `net40` one, byte for byte. The patched build has **identical type and method metadata** to both pristine builds and differs in 548 lines of IL — same version, same public surface, different code. If a file set is mixed between builds, you get failures with no obvious relation to the file that is wrong. Compare hashes.

### Rebuilding it yourself

The edit is in Cecil's own source ([jbevain/cecil](https://github.com/jbevain/cecil), `0.11.4.0`): make `Mono.Cecil.Pdb.PdbWriterProvider.GetSymbolWriter` and `Mono.Cecil.Pdb.NativePdbWriterProvider.GetSymbolWriter` / `CreateWriter` return `null` instead of constructing a writer. Everything else stays upstream.

We do not have the tree it was built from, so the released binary is the artifact of record and the edit above is its meaning.

---

## Other failures on this stack (not fixed by this patch)

Real, but unrelated. Match by shape, not by the method named.

**`InvalidProgramException` in a `DMD` wrapper**, while a mod is loading:

```text
System.InvalidProgramException: Invalid IL code in [wrapper dynamic-method]
Celeste.ScreenWipe:DMD<Celeste.ScreenWipe::get_Bottom> (Celeste.ScreenWipe): IL_000f: ret

  at MonoMod.RuntimeDetour.Platforms.DetourRuntimeILPlatform.GetFunctionPointer(MethodBase, RuntimeMethodHandle)
  at MonoMod.RuntimeDetour.Detour._TopApply()
  at MonoMod.RuntimeDetour.ILHook..ctor(MethodBase, ILContext+Manipulator, ILHookConfig)
```

A hook produced a wrapper the runtime rejected. The method named is just whichever one the mod hooked first — a red herring. Well-behaved mods catch this and log a warning instead of dying.

**`MissingMethodException` while a mod loads** (`Method not found: void .<>c..ctor(...)`): that mod was built against an **Everest-merged `Celeste.dll`**. Build against the pristine game assembly plus `Celeste.Mod.mm.dll` separately.

**Nothing at all — no `[Everest] Booting`, process at ~0% CPU, Steam waiting.** Not slow, dead. Restart Steam rather than waiting, then work through the two cases above.

## Traps

- **Steam "verify integrity" and auto-update re-patch or overwrite `Celeste.exe`,** which can put the unpatched Cecil back. Keep auto-update off for Celeste, and re-copy these two files if you ever verify.
- **A launch option cannot change the runtime.** `WINEDLLOVERRIDES="mscoree=b" %command%` prepends to what the handheld's config already sets, and loses.
- **Mods must target `net472`.** Wine-Mono cannot load a `net8.0` assembly, so a .NET 8 mod will fail to load with no useful message.
- **Mixed file sets are the classic self-inflicted wound.** Copy the whole MonoMod/Cecil set from one build, never a file at a time from two.

## Open questions

- Whether a pristine Everest install ever survives its first patch on this stack without the stubbed Cecil. Every device we set up needed it, but that is not proof.
- `MonoMod.exe` ships here unmodified. If your working install runs a different one, that is a data point we would like.

## Credits and licensing

`Mono.Cecil` is © Jb Evain and contributors (MIT, <https://github.com/jbevain/cecil>); `MonoMod` is © the MonoMod contributors (MIT, <https://github.com/MonoMod/MonoMod>). The Cecil build here is modified, and the modification is described above in full. Readers were left alone.

Celeste is © Maddy Makes Games Inc. — no game files are included here, ever. Neither is Everest. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Notes and packaging in this repo are MIT; see [LICENSE](LICENSE).
