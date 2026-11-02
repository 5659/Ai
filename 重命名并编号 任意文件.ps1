# 给文件编号（可选：只处理图片/视频，或所有文件）；视频名末尾追加时长；文件夹名前加上其内文件的编号范围。先预览，确认后才执行。
$KeepOriginalName = $false  # $false = 文件名只保留编号(+时长)，丢弃原名；$true = 保留原名，如 0001_原名.jpg
$AllFiles         = $true   # $true = 处理所有类型的文件；$false = 只处理下面列出的图片/视频
$GlobalNumbering  = $true   # $true = 全部文件连续编号；$false = 每个文件夹各自从0001开始
$RenameFolders    = $true   # $true = 文件夹名前加编号范围，如 0005-0020-A

# ===== 起始编号 =====
# 想让编号从几号开始，就改下面这个数字。例：1 → 0001 开始；101 → 0101 开始；1001 → 1001 开始
# $GlobalNumbering = $true 时：整批文件只从这个编号开始，往后连续编号
# $GlobalNumbering = $false 时：每个文件夹都各自从这个编号开始
# 文件夹名里的编号范围会跟着变，例如 0101-0120-A
$StartNumber = 1

$Root = (Get-Location).Path
# 要处理的视频格式；有漏掉的后缀，照样子加在后面即可
$vidExt = '.mp4','.mkv','.avi','.mov','.wmv','.flv','.ts','.m4v','.3gp','.3g2','.mts','.m2ts','.mpg','.mpeg','.webm','.rmvb','.rm','.asf','.vob'
# 要处理的图片格式
$imgExt = '.jpg','.jpeg','.png','.gif','.bmp','.webp','.heic'
$allExt = $vidExt + $imgExt

if (-not (Get-Command ffprobe -ErrorAction SilentlyContinue)) {
    Write-Host '未找到 ffprobe，请先安装 FFmpeg 并加入 Path（或把 ffprobe.exe 放在本脚本旁边）' -ForegroundColor Red
    Read-Host '按回车退出'; exit
}

$script:n = $StartNumber - 1   # 计数器初值 = 起始编号 - 1（第一个文件会先 +1）
$script:plan = @()
$script:folders = @()

function Get-Dur($file) {
    $out = & ffprobe -v error -show_entries format=duration -of csv=p=0 -- $file 2>$null
    $sec = 0.0
    if ([double]::TryParse(($out | Select-Object -First 1), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$sec)) {
        $t = [TimeSpan]::FromSeconds([math]::Round($sec))
        return '_{0:00}.{1:00}.{2:00}' -f [int][math]::Floor($t.TotalHours), $t.Minutes, $t.Seconds
    }
    return '_时长未知'
}

function Walk([string]$dir, [bool]$isRoot) {
    if (-not $GlobalNumbering) { $script:n = $StartNumber - 1 }   # 每个文件夹各自编号时，从起始编号重新开始
    $first = $script:n + 1
    $items = Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -ne $PSCommandPath -and $_.Name -notin 'rename_log.csv','rename_folder_log.csv' -and
            ($AllFiles -or $allExt -contains $_.Extension.ToLower())
        } | Sort-Object Name
    foreach ($f in $items) {
        $script:n++
        $ext = $f.Extension.ToLower()
        $base = if ($KeepOriginalName) { '_' + $f.BaseName } else { '' }
        $dur = if ($vidExt -contains $ext) { Get-Dur $f.FullName } else { '' }
        $new = ('{0:0000}{1}{2}{3}' -f $script:n, $base, $dur, $f.Extension)
        $script:plan += [pscustomobject]@{ Dir = $dir; Old = $f.Name; New = $new }
    }
    $directLast = $script:n
    $subs = Get-ChildItem -LiteralPath $dir -Directory -ErrorAction SilentlyContinue |
        Where-Object { -not ($_.Attributes -band ([IO.FileAttributes]::System -bor [IO.FileAttributes]::Hidden -bor [IO.FileAttributes]::ReparsePoint)) } |
        Sort-Object Name
    foreach ($s in $subs) { Walk $s.FullName $false }
    $last = if ($GlobalNumbering) { $script:n } else { $directLast }
    if (-not $isRoot -and $last -ge $first) {
        $leaf = Split-Path $dir -Leaf
        $newName = if ($first -eq $last) { '{0:0000}-{1}' -f $first, $leaf } else { '{0:0000}-{1:0000}-{2}' -f $first, $last, $leaf }
        $script:folders += [pscustomobject]@{ Path = $dir; Old = $leaf; New = $newName }
    }
}

Write-Host "正在扫描 $Root ..."
Walk $Root $true

if ($script:plan.Count -eq 0) { Write-Host '没有找到可处理的文件'; Read-Host '按回车退出'; exit }

Write-Host "`n文件预览（前 20 条，共 $($script:plan.Count) 个）：" -ForegroundColor Cyan
$script:plan | Select-Object -First 20 | ForEach-Object { Write-Host "$($_.Old)  ->  $($_.New)" }
if ($RenameFolders) {
    Write-Host "`n文件夹预览（前 20 条，共 $($script:folders.Count) 个）：" -ForegroundColor Cyan
    $script:folders | Select-Object -First 20 | ForEach-Object { Write-Host "$($_.Old)  ->  $($_.New)" }
}

$ans = Read-Host "`n确认重命名？(Y/N)"
if ($ans -notin 'Y','y') { Write-Host '已取消'; Read-Host '按回车退出'; exit }

$script:plan | Export-Csv -LiteralPath (Join-Path $Root 'rename_log.csv') -NoTypeInformation -Encoding UTF8
foreach ($p in $script:plan) {
    try { Rename-Item -LiteralPath (Join-Path $p.Dir $p.Old) -NewName $p.New -ErrorAction Stop }
    catch { Write-Host "失败：$($p.Old) - $($_.Exception.Message)" -ForegroundColor Yellow }
}
if ($RenameFolders) {
    $script:folders | Export-Csv -LiteralPath (Join-Path $Root 'rename_folder_log.csv') -NoTypeInformation -Encoding UTF8
    # 从最深的文件夹开始改，避免上级改名后下级路径失效
    foreach ($d in ($script:folders | Sort-Object { $_.Path.Length } -Descending)) {
        try { Rename-Item -LiteralPath $d.Path -NewName $d.New -ErrorAction Stop }
        catch { Write-Host "文件夹失败：$($d.Old) - $($_.Exception.Message)" -ForegroundColor Yellow }
    }
}
Write-Host "完成！对照记录已保存到 rename_log.csv / rename_folder_log.csv" -ForegroundColor Green
Read-Host '按回车退出'
