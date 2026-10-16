# celeste-proton-arm64

Field notes for running **Celeste + Everest on an ARM64 Android handheld** (Steam + Proton + FEX translation + Wine-Mono), and for recognising the handful of failures that look like mod bugs but are not.

Verified on a Retroid Pocket Nova through DroidDeck, and a DroidDeck-class handheld: Celeste `1.4.0.0-fna`, Everest `4449-azure-ddba3`.

This is not a patch and not affiliated with Everest, MonoMod or Celeste. It is a description of an install that works, plus the stacks to look for when yours does not.

## The short version

Celeste's Windows build runs under Proton, which means Wine's .NET runtime (Wine-Mono) plus x86→ARM translation, and Everest patches the game with MonoMod on first launch. Almost every "it will not boot on the handheld" case we hit was one of three things:

1. **A mod built for the wrong runtime.** Wine-Mono cannot load a `net8.0` assembly. Mods must target `net472`.
2. **A MonoMod/Cecil file set assembled from more than one build.** Nothing is *broken*, something is *mixed* — usually because the game folder was copied between machines, or DLLs were hand-swapped while troubleshooting.
3. **A mod built against an Everest-merged `Celeste.dll`.** Compiles clean, dies while loading.

## Recognise it by the stack

### 1. Invalid IL code in a `DMD` wrapper

```text
System.InvalidProgramException: Invalid IL code in [wrapper dynamic-method]
Celeste.ScreenWipe:DMD<Celeste.ScreenWipe::get_Bottom> (Celeste.ScreenWipe): IL_000f: ret

  at [wrapper managed-to-native] System.RuntimeMethodHandle.GetFunctionPointer(intptr)
  at MonoMod.RuntimeDetour.Platforms.DetourRuntimeILPlatform.GetFunctionPointer(MethodBase, RuntimeMethodHandle)
  at MonoMod.RuntimeDetour.Platforms.DetourRuntimeILPlatform.GetNativeStart(MethodBase)
  at MonoMod.RuntimeDetour.Detour._TopApply()
  at MonoMod.RuntimeDetour.ILHook..ctor(MethodBase, ILContext+Manipulator, ILHookConfig)
  at Celeste.Mod.CelesteFit.CelesteFitModule.HookMethod(Type, String, ILContext+Manipulator)
```

Read it bottom-up. Something applied an `ILHook` to a trivial getter, MonoMod built the wrapper for it by copying the original body out of the assembly **through Cecil**, and the runtime rejected what came out. This is the single most misleading error in the whole bring-up: it points at `GetFunctionPointer`, which is nowhere near the cause, and it names a *random* method — whichever one the mod happened to hook first.

Cause on our units: the `MonoMod.exe` / `Mono.Cecil.Pdb.dll` files in the install did not come from the same build as the rest of the set. Installing a matching pair stopped it. The pair that works on ours is in [`handheld/`](handheld/PROVENANCE.md).

This is also why well-behaved mods catch hook failures instead of throwing: one unhookable getter should cost you one patch, not the whole mod load.

### 2. MissingMethodException while a mod loads

```text
System.MissingMethodException: Method not found: void .<>c..ctor(int,int,Celeste.Mod.LogLevel,string,bool)
  at Celeste.Mod.CelesteFit.CelesteFitModule.Load ()
  at Celeste.Mod.Everest+Loader.LoadModAssembly (...)
```

The mod was built against an **Everest-merged `Celeste.dll`**. It compiles fine and fails here. Build against the pristine game assembly plus `Celeste.Mod.mm.dll` as a separate reference:

```text
Celeste.dll        Celeste.Mod.mm.dll     FNA.dll
MonoMod.Utils.dll  MonoMod.RuntimeDetour.dll   Mono.Cecil.dll
```

### 3. No error at all

`log.txt` never gets an `[Everest] Booting` line, and the process sits at ~0% CPU, state `S`. That is not a slow boot, it is blocked or dead — a Wine-Mono crash can leave the process alive and idle, so Steam waits forever. Restart Steam rather than waiting, then work through the two cases above.

## The install set that works

These must all come from **one** Everest build. Reported assembly versions from our working unit:

| File | Version | Notes |
| --- | --- | --- |
| `MonoMod.exe` | `22.1.4.3` | the patcher CLI |
| `MonoMod.Utils.dll` | `22.1.4.3` | |
| `MonoMod.RuntimeDetour.dll` | `22.1.4.3` | what mod IL hooks use |
| `MonoMod.Core.dll` | `1.3.1.0` | |
| `MonoMod.Patcher.dll` | `0.0.0.0` | |
| `Mono.Cecil.dll` | `0.11.4.0` | |
| `Mono.Cecil.Pdb.dll` | `0.11.4.0` | the file that bit us — see below |

**Matching versions do not mean matching files.** The macOS and Windows Everest 4449 releases both ship a `Mono.Cecil.Pdb.dll` that reports `0.11.4.0`, and they are not the same binary: 89600 bytes (macOS) versus 88064 bytes (Windows). The 88064-byte one is what works for us. Do not pick files by reported version, and do not cross-copy between platform builds.

`scripts/check-files.sh /path/to/Celeste` prints size and SHA-256 for the whole set so you can compare against [`handheld/PROVENANCE.md`](handheld/PROVENANCE.md).

## Installing the pair

Copy both files from [`handheld/`](handheld/) into the folder holding `Celeste.exe`, replacing what is there, and keep a backup of the originals. Then launch once and watch `log.txt`.

## Deploying mods to the handheld

`adb` connects as the unprivileged `shell` user, which cannot write Steam's game folder. The loop is:

```bash
adb push MyMod.zip /sdcard/Download/
```

then copy the zip from `/sdcard/Download` into `Celeste/Mods/` from a terminal **on the device**, and start the game. Everest installs it on boot.

## Traps

- **Steam "verify integrity" and auto-update overwrite the patched `Celeste.exe`.** Keep auto-update off for this game, or re-run Everest afterwards.
- **Launch options cannot change the .NET runtime.** `WINEDLLOVERRIDES="mscoree=b" %command%` prepends to a value the handheld's own Proton config already sets, so it does not win.
- **0% CPU is dead, not slow.** See case 3.
- **A fresh install beats a repaired one.** If the set is mixed, re-extract Everest for that install rather than swapping files one at a time; a half-swapped install is how we got here.

## What we do not know

- **Why the `Mono.Cecil.Pdb.dll` binary matters at all.** Both candidates report version `0.11.4.0` and both are plain IL assemblies, so the difference is presumably in how they are built (framework target, facades) rather than what they claim to be. This is inferred from "it stopped failing after the swap", not proven.
- **Whether a clean, consistent install ever shows the `DMD` failure.** Every device we touched had already been assembled by copying folders between machines. If you set one up from scratch and it boots fine, that is a data point — open an issue.
- **Strawberry Jam and other large mod packs** are untested on ARM here.

## Worked example

[**celeste-43aspect**](https://github.com/jevonlipsey/celeste-43aspect) is a 4:3 aspect-ratio mod for PC Celeste that runs on exactly this stack, and its `docs/HANDHELD-NOTES.md` is where the notes above came from. If you want to see a mod that survives all of this, start there.

## If you are stuck

Open an issue with: the device, the Proton/FEX version, Celeste + Everest build strings from the top of `log.txt`, and the full stack trace. The stack is what identifies the case.
