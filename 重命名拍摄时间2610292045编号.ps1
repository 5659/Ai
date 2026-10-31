# 给图片/视频改名。两种模式：按拍摄时间命名(time) / 按编号命名(number)。先预览，确认后才执行。
$NameMode         = 'time'        # 'time' = 按拍摄时间；'number' = 按编号
$TimeFormat       = 'yyMMddHHmm'  # 时间格式：yy年 MM月 dd日 HH时 mm分（想精确到秒就加 ss）
$KeepVideoDuration = $true        # 视频名末尾是否追加时长
$KeepOriginalName = $false        # 仅 number 模式：是否保留原名
$GlobalNumbering  = $true         # 仅 number 模式：$true=全部连续编号；$false=每个文件夹各自从0001开始
$RenameFolders    = $true         # 仅 number 模式：文件夹名前加编号范围，如 0005-0020A

$Root = (Get-Location).Path
$vidExt = '.mp4','.mkv','.avi','.mov','.wmv','.flv','.ts','.m4v'
$imgExt = '.jpg','.jpeg','.png','.gif','.bmp','.webp','.heic'
$allExt = $vidExt + $imgExt
$inv = [Globalization.CultureInfo]::InvariantCulture
Add-Type -AssemblyName System.Drawing

if (-not (Get-Command ffprobe -ErrorAction SilentlyContinue)) {
    Write-Host '未找到 ffprobe，请先安装 FFmpeg 并加入 Path（或把 ffprobe.exe 放在本脚本旁边）' -ForegroundColor Red
    Read-Host '按回车退出'; exit
}

$script:n = 0
$script:plan = @()
$script:folders = @()
$script:fallback = 0
$script:shell = $null

function Format-Dur([double]$sec) {
    $t = [TimeSpan]::FromSeconds([math]::Round($sec))
    return '_{0:00}.{1:00}.{2:00}' -f [int][math]::Floor($t.TotalHours), $t.Minutes, $t.Seconds
}

# 读视频：时长 + 拍摄时间
function Get-VideoInfo($file) {
    $res = @{ Dur = '_时长未知'; Time = $null }
    try {
        $out = & ffprobe -v error -show_entries 'format=duration:format_tags' -of json -- $file 2>$null
        $j = ($out -join "`n") | ConvertFrom-Json
        $sec = 0.0
        if ([double]::TryParse([string]$j.format.duration, [Globalization.NumberStyles]::Float, $inv, [ref]$sec)) { $res.Dur = Format-Dur $sec }
        $tags = $j.format.tags
        if ($tags) {
            $cd = $tags.'com.apple.quicktime.creationdate'
            if ($cd) {
                $res.Time = [datetime]::ParseExact($cd.Substring(0,19), 'yyyy-MM-ddTHH:mm:ss', $inv)
            } elseif ($tags.creation_time) {
                $u = [datetime]::ParseExact(([string]$tags.creation_time).Substring(0,19), 'yyyy-MM-ddTHH:mm:ss', $inv)
                $res.Time = [datetime]::SpecifyKind($u, 'Utc').ToLocalTime()
            }
        }
    } catch {}
    return $res
}

# 读图片拍摄时间：先 EXIF，再 Windows“拍摄日期”属性
function Get-PhotoTime($file) {
    $fs = $null; $img = $null
    try {
        $fs = [IO.File]::Open($file, 'Open', 'Read', 'ReadWrite')
        $img = [Drawing.Image]::FromStream($fs, $false, $false)
        if ($img.PropertyIdList -contains 0x9003) {
            $s = [Text.Encoding]::ASCII.GetString($img.GetPropertyItem(0x9003).Value).Trim([char]0).Trim()
            return [datetime]::ParseExact($s, 'yyyy:MM:dd HH:mm:ss', $inv)
        }
    } catch {} finally {
        if ($img) { $img.Dispose() }
        if ($fs) { $fs.Dispose() }
    }
    try {
        if (-not $script:shell) { $script:shell = New-Object -ComObject Shell.Application }
        $ns = $script:shell.NameSpace((Split-Path $file))
        $item = $ns.ParseName((Split-Path $file -Leaf))
        $s = $ns.GetDetailsOf($item, 12)
        $m = [regex]::Matches($s, '\d+')
        if ($m.Count -ge 5) {
            $y = [int]$m[0].Value; if ($y -lt 100) { $y += 2000 }
            return [datetime]::new($y, [int]$m[1].Value, [int]$m[2].Value, [int]$m[3].Value, [int]$m[4].Value, 0)
        }
    } catch {}
    return $null
}

function Walk([string]$dir, [bool]$isRoot) {
    if ($NameMode -eq 'number' -and -not $GlobalNumbering) { $script:n = 0 }
    $first = $script:n + 1
    $items = @(Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue |
        Where-Object { $allExt -contains $_.Extension.ToLower() } | Sort-Object Name)

    if ($NameMode -eq 'time') {
        $rows = @(foreach ($f in $items) {
            $isVid = $vidExt -contains $f.Extension.ToLower()
            $dur = ''; $t = $null
            if ($isVid) { $info = Get-VideoInfo $f.FullName; $t = $info.Time; $dur = $info.Dur }
            else { $t = Get-PhotoTime $f.FullName }
            if (-not $t) { $t = $f.LastWriteTime; $script:fallback++ }
            [pscustomobject]@{ F = $f; T = $t; Vid = $isVid; Dur = $dur }
        })
        $seen = @{}
        foreach ($r in ($rows | Sort-Object T, { $_.F.Name })) {
            $key = $r.T.ToString($TimeFormat) + $r.F.Extension.ToLower()
            $c = 1 + [int]$seen[$key]; $seen[$key] = $c
            $suffix = if ($c -gt 1) { "-$c" } else { '' }
            $d = if ($r.Vid -and $KeepVideoDuration) { $r.Dur } else { '' }
            $new = '{0}{1}{2}{3}' -f $r.T.ToString($TimeFormat), $suffix, $d, $r.F.Extension
            if ($new -ne $r.F.Name) { $script:plan += [pscustomobject]@{ Dir = $dir; Old = $r.F.Name; New = $new } }
        }
    } else {
        foreach ($f in $items) {
            $script:n++
            $isVid = $vidExt -contains $f.Extension.ToLower()
            $base = if ($KeepOriginalName) { '_' + $f.BaseName } else { '' }
            $d = ''
            if ($isVid -and $KeepVideoDuration) { $d = (Get-VideoInfo $f.FullName).Dur }
            $new = '{0:0000}{1}{2}{3}' -f $script:n, $base, $d, $f.Extension
            $script:plan += [pscustomobject]@{ Dir = $dir; Old = $f.Name; New = $new }
        }
    }
    $directLast = $script:n

    $subs = Get-ChildItem -LiteralPath $dir -Directory -ErrorAction SilentlyContinue |
        Where-Object { -not ($_.Attributes -band ([IO.FileAttributes]::System -bor [IO.FileAttributes]::Hidden -bor [IO.FileAttributes]::ReparsePoint)) } |
        Sort-Object Name
    foreach ($s in $subs) { Walk $s.FullName $false }

    if ($NameMode -eq 'number' -and $RenameFolders) {
        $last = if ($GlobalNumbering) { $script:n } else { $directLast }
        if (-not $isRoot -and $last -ge $first) {
            $leaf = Split-Path $dir -Leaf
            $newName = if ($first -eq $last) { '{0:0000}{1}' -f $first, $leaf } else { '{0:0000}-{1:0000}{2}' -f $first, $last, $leaf }
            $script:folders += [pscustomobject]@{ Path = $dir; Old = $leaf; New = $newName }
        }
    }
}

Write-Host "正在扫描 $Root （读取拍摄时间/时长，文件多时请稍等）..."
Walk $Root $true

if ($script:plan.Count -eq 0) { Write-Host '没有需要改名的图片/视频'; Read-Host '按回车退出'; exit }

Write-Host "`n文件预览（前 20 条，共 $($script:plan.Count) 个）：" -ForegroundColor Cyan
$script:plan | Select-Object -First 20 | ForEach-Object { Write-Host "$($_.Old)  ->  $($_.New)" }
if ($script:folders.Count -gt 0) {
    Write-Host "`n文件夹预览（前 20 条，共 $($script:folders.Count) 个）：" -ForegroundColor Cyan
    $script:folders | Select-Object -First 20 | ForEach-Object { Write-Host "$($_.Old)  ->  $($_.New)" }
}
if ($script:fallback -gt 0) {
    Write-Host "`n提示：有 $($script:fallback) 个文件读不到拍摄时间，已改用文件修改时间。" -ForegroundColor Yellow
}

$ans = Read-Host "`n确认重命名？(Y/N)"
if ($ans -notin 'Y','y') { Write-Host '已取消'; Read-Host '按回车退出'; exit }

$script:plan | Export-Csv -LiteralPath (Join-Path $Root 'rename_log.csv') -NoTypeInformation -Encoding UTF8
foreach ($p in $script:plan) {
    try { Rename-Item -LiteralPath (Join-Path $p.Dir $p.Old) -NewName $p.New -ErrorAction Stop }
    catch { Write-Host "失败：$($p.Old) - $($_.Exception.Message)" -ForegroundColor Yellow }
}
if ($script:folders.Count -gt 0) {
    $script:folders | Export-Csv -LiteralPath (Join-Path $Root 'rename_folder_log.csv') -NoTypeInformation -Encoding UTF8
    foreach ($d in ($script:folders | Sort-Object { $_.Path.Length } -Descending)) {
        try { Rename-Item -LiteralPath $d.Path -NewName $d.New -ErrorAction Stop }
        catch { Write-Host "文件夹失败：$($d.Old) - $($_.Exception.Message)" -ForegroundColor Yellow }
    }
}
Write-Host '完成！对照记录已保存到 rename_log.csv' -ForegroundColor Green
Read-Host '按回车退出'
