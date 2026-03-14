---
name: nxbuild
description: Execute NeoX engine builds using nxb-*.ps1 CLI wrappers. Supports Windows (VS2019/VS2022), Android, Web, and Minigame platforms. Use when the user wants to build NeoX engine, run nxbuild commands, or troubleshoot build issues.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
argument-hint: "<platform> [options] — e.g. windows, android --dry-run, all"
---

# NXBuild Skill

Execute NeoX engine builds using the nxb-*.ps1 CLI tools. Supports Windows (VS2019/VS2022), Android, Web, and Minigame platforms.

## Arguments

$ARGUMENTS — Platform and options. Format: `<platform> [options]`

Platforms: `windows`, `android`, `web`, `minigame`, `all`
Options: `--dry-run`, `--clean`, `--no-ib`, `--config <Debug|Release>`, `--target <name>`

Examples:
- `/nxbuild windows` — Build Windows VS2019 x64 Release with IncrediBuild
- `/nxbuild android --dry-run` — DryRun Android build
- `/nxbuild web --clean` — Clean then build Web
- `/nxbuild all` — Build all 4 platforms (directory-isolated)
- `/nxbuild windows --config Debug --no-ib` — Debug build without IncrediBuild
- `/nxbuild minigame --target NeoX` — Build specific target for minigame

## Architecture — Build Call Chain

```
nxb-build.ps1 (CLI wrapper)               ← replaces nxbuild_launcher.py GUI
    │
    └─→ python -m nxbuild build            ← nxbuild framework (pip package)
            │
            ├─→ neox.nxbuild.py            ← project config (NeoX source root)
            │       │ platform detection:
            │       │   windows → VS toolchain
            │       │   android → NDK + Gradle
            │       │   web/minigame → emscripten + AUDIO_USE_NULL_LOGIC=True
            │       │
            │       └─→ audio2.nxbuild.py, render.nxbuild.py, ...
            │           (module configs, recursively discovered)
            │
            ├─→ conan install              ← third-party deps (wwise, boost, ...)
            ├─→ cmake configure            ← generate build system
            └─→ cmake --build             ← compile
```

## Platform Configurations

### Windows (VS2019 x64)
```powershell
.\nxb-build.ps1 -SolutionDir $SRC -Toolchain vs2019_x64 -Configuration Release -IncrediBuild
```
- Toolchain: `vs2019_x64` or `vs2022`
- IncrediBuild: supported, significantly speeds up MSBuild
- BuildDir defaults to SolutionDir (cwd)

### Android (arm64-v8a)
```powershell
.\nxb-build.ps1 -SolutionDir $SRC -BuildDir "$SRC\BuildAndroid" `
    -Toolchain android -Configuration Release -IncrediBuild `
    -Settings "ANDROID_ABI=arm64-v8a"
```
- Toolchain: `android` (NOT `android_arm64`)
- ABI via Settings: `ANDROID_ABI=arm64-v8a`
- **MUST use separate BuildDir** from Windows (multiple .sln conflict)

### Web (Emscripten → WASM)
```powershell
.\nxb-build.ps1 -SolutionDir $SRC -BuildDir "$SRC\BuildWeb" `
    -Toolchain web -Configuration Release -IncrediBuild
```
- Toolchain: `web` (NOT `web_emscripten_wasm32`)
- `AUDIO_USE_NULL_LOGIC=True` forced by neox.nxbuild.py

### Minigame
```powershell
.\nxb-build.ps1 -SolutionDir $SRC -BuildDir "$SRC\BuildMinigame" `
    -Toolchain web -Configuration Release -IncrediBuild `
    -Settings "NEOX_UPLOAD_NAME=nxplayer_minigame_neox3"
```
- Same as Web, plus `NEOX_UPLOAD_NAME` setting

## CLI Tools Reference

| Script | Command | Default Timeout | Notes |
|--------|---------|-----------------|-------|
| `nxb-configure.ps1` | configure | 30 min | |
| `nxb-generate.ps1` | generate | 60 min | |
| `nxb-build.ps1` | build | 120 min | auto-runs configure+generate if stale |
| `nxb-build-targets.ps1` | build_targets | 120 min | has -Target param |
| `nxb-clean.ps1` | clean | 10 min | |
| `nxb-install.ps1` | install | 30 min | |

All scripts share params: `-SolutionDir`, `-BuildDir`, `-Toolchain`, `-Configuration`, `-ProjectGenerator`, `-Settings`, `-NxBuildVenv`, `-TimeoutMinutes`, `-DryRun`

Build/BuildTargets also accept: `-IncrediBuild`, `-Target`

## Configuration

Paths are read from `project_config.json` in the CLI repo root:
```json
{
    "GitRepoUrl": "http://git-internal.nie.netease.com/NeoX/NeoX.git",
    "BranchName": "neox3_master",
    "WorkPath": "WorkPath",
    "SolutionDir": "WorkPath/NeoX"
}
```

## Venv Discovery Chain

`nxb-common.ps1 → Find-NxBuildPython` resolves Python in this order:
1. Explicit `-NxBuildVenv` param
2. MD5 hash of `$SolutionDir/requirements.txt` → `~/.nxbuild/nxbuild_venv_{hash}/`
3. Default `~/.nxbuild/nxbuild_venv/`
4. Newest `~/.nxbuild/nxbuild_venv*/` by LastWriteTime
5. Bootstrap via `nxbuild_launcher.py --no-gui -- --help`
6. Error exit

## Directory Isolation

Each platform **must have its own BuildDir**:
```
WorkPath/NeoX/              ← SolutionDir (shared)
WorkPath/NeoX/BuildAndroid/ ← Android BuildDir
WorkPath/NeoX/BuildWeb/     ← Web BuildDir
WorkPath/NeoX/BuildMinigame/← Minigame BuildDir
```

## Troubleshooting

### Conan wwise self-deadlock
Symptom: `wwise/... is locked by another concurrent conan process, wait...` — hangs indefinitely.

**Root cause**: Conan's `WriteLock` is **not re-entrant**. Same process acquires write lock twice → infinite loop.

**Fix**: `nxb-common.ps1` temporarily sets `CONAN_CACHE_NO_LOCKS=True` during builds.

**If a build gets killed mid-run**:
```powershell
Get-Process python* | Stop-Process -Force
Get-ChildItem "$env:USERPROFILE\.conan\data" -Recurse -Filter "*.lock" | Remove-Item -Force
Get-ChildItem "$env:USERPROFILE\.conan\data" -Recurse -Filter "*.count" | Where-Object { (Get-Content $_) -ne "0" } | ForEach-Object { Set-Content $_ "0" }
```

### Wrong toolchain name
- Android: use `android`, not `android_arm64`
- Web/Minigame: use `web`, not `web_emscripten_wasm32`

## Instructions for Claude

When the user invokes `/nxbuild`:

1. Parse the platform from $ARGUMENTS. Default to `windows` if not specified. Default config is `Release`.

2. Resolve paths from `project_config.json`:
   ```powershell
   $CLI = "<NeoXBuildAutomation repo root>"
   $config = Get-Content "$CLI\project_config.json" -Raw | ConvertFrom-Json
   $SRC = Join-Path $CLI $config.SolutionDir
   ```
   If `project_config.json` doesn't exist or `SolutionDir` is missing, ask the user for the NeoX source path.

3. If `--clean` specified, run `nxb-clean.ps1` first.

4. If `--dry-run` specified, add `-DryRun` flag.

5. Build the PowerShell command per platform config above. Use `-IncrediBuild` unless `--no-ib`.

6. For `all`: launch 4 builds with directory isolation. Run Windows first (uses default BuildDir), then others in parallel with separate BuildDirs.

7. Run via `powershell -ExecutionPolicy Bypass -File "$CLI\nxb-build.ps1" ...`

8. For long builds, use `run_in_background: true` and report progress when asked.

9. On conan lock errors: kill python processes, delete all `.lock` files under `~/.conan/data/`, retry.
