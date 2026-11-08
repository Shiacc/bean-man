# 一键切换仓库可见性（不需要开浏览器，也不需要 Actions）。
#
#   powershell -ExecutionPolicy Bypass -File .\Scripts\repo_visibility.ps1 -Target private
#   powershell -ExecutionPolicy Bypass -File .\Scripts\repo_visibility.ps1 -Target public
#
# 令牌默认读 C:\Users\lenovo\.dsh\secrets\github-pat.txt（也可用 -TokenFile 指定）。
# 说明：本机执行策略默认禁止跑 .ps1，所以要带 -ExecutionPolicy Bypass。
param(
    [ValidateSet('private', 'public')]
    [string]$Target = 'private',
    [string]$Repo = 'Shiacc/bean-man',
    [string]$TokenFile = 'C:\Users\lenovo\.dsh\secrets\github-pat.txt'
)

if (-not (Test-Path $TokenFile)) {
    throw "找不到令牌文件：$TokenFile"
}

$token = (Get-Content $TokenFile -Raw).Trim()
if ([string]::IsNullOrWhiteSpace($token)) { throw "令牌文件是空的：$TokenFile" }

$body = if ($Target -eq 'private') { '{"private":true}' } else { '{"private":false}' }
$headers = @{
    Authorization          = "Bearer $token"
    Accept                 = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
}

Write-Host "正在把 $Repo 切换为 $Target ..." -ForegroundColor Cyan
$resp = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo" -Method Patch `
    -Headers $headers -Body $body -ContentType 'application/json'

Write-Host ("完成：visibility={0}  private={1}" -f $resp.visibility, $resp.private) -ForegroundColor Green
if ($Target -eq 'private') {
    Write-Host "提醒：私有仓库的 macOS runner 按 10x 计费（2000 分钟/月 ≈ 200 分钟 macOS）。" -ForegroundColor Yellow
}