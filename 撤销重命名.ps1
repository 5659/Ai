# 撤销重命名：根据 rename_log.csv / rename_folder_log.csv 把文件和文件夹改回原名。先预览，确认后才执行。
# 用法：把本脚本放到【当初运行重命名脚本的同一个文件夹】里运行（日志文件就在那里）。
# 注意：日志每次运行重命名脚本都会被覆盖，所以只能撤销【最近一次】的重命名。

$Root       = (Get-Location).Path
$fileLog    = Join-Path $Root 'rename_log.csv'
$folderLog  = Join-Path $Root 'rename_folder_log.csv'

if (-not (Test-Path -LiteralPath $fileLog) -and -not (Test-Path -LiteralPath $folderLog)) {
    Write-Host '当前文件夹里没有找到 rename_log.csv / rename_folder_log.csv' -ForegroundColor Red
    Read-Host '按回车退出'; exit
}

$files   = @(); if (Test-Path -LiteralPath $fileLog)   { $files   = @(Import-Csv -LiteralPath $fileLog   -Encoding UTF8) }
$folders = @(); if (Test-Path -LiteralPath $folderLog) { $folders = @(Import-Csv -LiteralPath $folderLog -Encoding UTF8) }

Write-Host "`n将撤销：$($files.Count) 个文件，$($folders.Count) 个文件夹" -ForegroundColor Cyan
Write-Host "`n文件预览（前 20 条）：" -ForegroundColor Cyan
$files | Select-Object -First 20 | ForEach-Object { Write-Host "$($_.New)  ->  $($_.Old)" }
if ($folders.Count -gt 0) {
    Write-Host "`n文件夹预览（前 20 条）：" -ForegroundColor Cyan
    $folders | Select-Object -First 20 | ForEach-Object { Write-Host "$($_.New)  ->  $($_.Old)" }
}

$ans = Read-Host "`n确认撤销？(Y/N)"
if ($ans -notin 'Y','y') { Write-Host '已取消'; Read-Host '按回车退出'; exit }

# 第一步：先还原文件夹名（从最浅的开始，这样子文件夹的父路径已经是原名）
foreach ($d in ($folders | Sort-Object { $_.Path.Length })) {
    $cur = Join-Path (Split-Path $d.Path -Parent) $d.New
    try { Rename-Item -LiteralPath $cur -NewName $d.Old -ErrorAction Stop }
    catch { Write-Host "文件夹失败：$($d.New) - $($_.Exception.Message)" -ForegroundColor Yellow }
}

# 第二步：还原文件名。先全部改成临时名，再改回原名，避免“原名”恰好等于别的文件的编号名而冲突
$tmp = @()
foreach ($p in $files) {
    $cur = Join-Path $p.Dir $p.New
    $t   = '__undo_' + [guid]::NewGuid().ToString('N') + '.tmp'
    try {
        Rename-Item -LiteralPath $cur -NewName $t -ErrorAction Stop
        $tmp += [pscustomobject]@{ Dir = $p.Dir; Tmp = $t; Old = $p.Old; New = $p.New }
    } catch { Write-Host "失败：$($p.New) - $($_.Exception.Message)" -ForegroundColor Yellow }
}
foreach ($t in $tmp) {
    try { Rename-Item -LiteralPath (Join-Path $t.Dir $t.Tmp) -NewName $t.Old -ErrorAction Stop }
    catch { Write-Host "还原失败：$($t.New) -> $($t.Old) - $($_.Exception.Message)（临时名：$($t.Tmp)）" -ForegroundColor Yellow }
}

# 日志改名，防止重复撤销
if (Test-Path -LiteralPath $fileLog)   { Rename-Item -LiteralPath $fileLog   -NewName 'rename_log.undone.csv'        -Force }
if (Test-Path -LiteralPath $folderLog) { Rename-Item -LiteralPath $folderLog -NewName 'rename_folder_log.undone.csv' -Force }

Write-Host '完成！日志已改名为 *.undone.csv' -ForegroundColor Green
Read-Host '按回车退出'
