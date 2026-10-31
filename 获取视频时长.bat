@echo off
setlocal enabledelayedexpansion

:: 建议将此 .bat 文件以 ANSI 编码保存
:: 这样导出的 CSV 在中文 Windows 系统下不会乱码

:: 1. 清理旧的记录并写入表头
echo "所在文件夹","文件名","视频时长" > video_list.csv

echo 正在扫描子文件夹，请稍候...
echo ---------------------------------------

:: 2. 使用 /r 递归遍历当前目录及所有子目录
:: %%f 会获取完整路径
for /r %%f in (*.mp4 *.mkv *.avi *.mov *.wmv) do (
    
    :: 获取纯文件名
    set "filename=%%~nxf"
    :: 获取文件所在的文件夹名（不含完整路径，只取最后一级）
    set "folderpath=%%~dpf"
    for %%i in ("!folderpath!.") do set "foldername=%%~nxi"

    :: 3. 调用 ffprobe 获取时长
    for /f "tokens=*" %%a in ('ffprobe -v error -show_entries format^=duration -of default^=noprint_wrappers^=1:nokey^=1 -sexagesimal "%%f"') do (
        set "full_time=%%a"
        :: 截取前 8 位 HH:MM:SS
        set "short_time=!full_time:~0,8!"
        
        echo 处理中: [!foldername!] !filename!
        
        :: 4. 写入 CSV：增加了一列“所在文件夹”，方便你分类查看
        echo "!foldername!","!filename!","!short_time!" >> video_list.csv
    )
)

echo ---------------------------------------
echo 处理完成！结果已汇总至 video_list.csv
pause