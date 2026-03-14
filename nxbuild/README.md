# nxbuild — NeoX 引擎构建技能

通过 `nxb-*.ps1` CLI 脚本执行 NeoX 引擎构建，替代 `nxbuild_launcher.py` GUI。

## 支持平台

| 平台 | Toolchain | 说明 |
|------|-----------|------|
| Windows | `vs2019_x64` / `vs2022` | 支持 IncrediBuild |
| Android | `android` | ABI 通过 `-Settings "ANDROID_ABI=arm64-v8a"` 指定 |
| Web | `web` | Emscripten → WASM |
| Minigame | `web` | 同 Web，额外指定 `NEOX_UPLOAD_NAME` |

## 前置条件

- NeoX 源码（通过 `nxb-clone.ps1` 获取或手动 clone）
- nxbuild Python 包（通过 `nxbuild_launcher.py` 自动 bootstrap 的 venv）
- Windows 环境 + PowerShell

## 快速开始

```powershell
# 1. Clone 源码
.\nxb-clone.ps1

# 2. 构建 Windows Release
.\nxb-build.ps1 -SolutionDir WorkPath\NeoX -Toolchain vs2019_x64 -Configuration Release -IncrediBuild

# 3. 构建 Android
.\nxb-build.ps1 -SolutionDir WorkPath\NeoX -BuildDir WorkPath\NeoX\BuildAndroid `
    -Toolchain android -Configuration Release -Settings "ANDROID_ABI=arm64-v8a"
```

## CLI 脚本

| 脚本 | 命令 | 默认超时 |
|------|------|---------|
| `nxb-configure.ps1` | configure | 30 min |
| `nxb-generate.ps1` | generate | 60 min |
| `nxb-build.ps1` | build | 120 min |
| `nxb-build-targets.ps1` | build_targets | 120 min |
| `nxb-clean.ps1` | clean | 10 min |
| `nxb-install.ps1` | install | 30 min |
| `nxb-clone.ps1` | — | — |

## 配置

路径配置在 `project_config.json`：

```json
{
    "GitRepoUrl": "http://git-internal.nie.netease.com/NeoX/NeoX.git",
    "BranchName": "neox3_master",
    "WorkPath": "WorkPath",
    "SolutionDir": "WorkPath/NeoX"
}
```

## 源码

[NeoXBuildAutomation](http://git-internal.nie.netease.com/lanyang/neoxbuildautomation)
