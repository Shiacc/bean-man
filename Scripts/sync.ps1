# Windows 侧同步助手。
# 这台机器没有原生 git，所以转交给 WSL 里的 git 执行。
#
#   .\Scripts\sync.ps1
#   .\Scripts\sync.ps1 "feat: 今日页"
#
# 需要：WSL 已安装 git，且 Gitee 的 SSH key 配好（wsl ssh -T git@gitee.com 能通）。

param(
    [Parameter(Position = 0)]
    [string]$Message = ""
)

$ErrorActionPreference = "Stop"

# 仓库根 = 本脚本的上一级目录
$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path      # 例：D:\...\beanman-ios

# 转成 WSL 路径：D:\a\b -> /mnt/d/a/b
$drive = $root.Substring(0, 1).ToLower()
$rest = $root.Substring(2) -replace '\\', '/'
$wslPath = "/mnt/$drive$rest"

# 提交信息里的单引号要转义，避免拼进 shell 时断掉
$safeMessage = $Message -replace "'", "'\''"
$arg = if ([string]::IsNullOrWhiteSpace($safeMessage)) { "" } else { " '$safeMessage'" }

Write-Host "→ 在 WSL 中同步：$wslPath" -ForegroundColor Cyan
wsl.exe -e bash -lc "cd '$wslPath' && bash Scripts/sync.sh$arg"

if ($LASTEXITCODE -ne 0) {
    throw "同步失败（exit $LASTEXITCODE）"
}