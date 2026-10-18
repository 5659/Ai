#SingleInstance Force
files := []
Loop Files, A_WorkingDir "\*.*", "F"
{
    ; 排除当前正在运行的脚本
    if (A_LoopFileFullPath = A_ScriptFullPath)
        continue
    ; 保留完整文件名（包含扩展名）
    files.Push(A_LoopFileName)
}
; 排序
count := files.Length
Loop count - 1
{
    i := A_Index
    Loop count - i
    {
        j := A_Index
        if (CompareFiles(files[j], files[j + 1]) > 0)
        {
            temp := files[j]
            files[j] := files[j + 1]
            files[j + 1] := temp
        }
    }
}
result := ""
for name in files
    result .= name "`r`n"
A_Clipboard := result
ExitApp
CompareFiles(a, b)
{
    ; 去掉扩展名，仅用于排序
    aBase := RegExReplace(a, "\.[^.]+$")
    bBase := RegExReplace(b, "\.[^.]+$")
    ; =========================
    ; 纯数字开头
    ; =========================
    aNum := RegExMatch(aBase, "^\d")
    bNum := RegExMatch(bBase, "^\d")
    if (aNum && !bNum)
        return -1
    if (!aNum && bNum)
        return 1
    if (aNum && bNum)
    {
        n1 := Integer(RegExReplace(aBase, "^(\d+).*", "$1"))
        n2 := Integer(RegExReplace(bBase, "^(\d+).*", "$1"))
        if (n1 != n2)
            return n1 - n2
        return StrCompare(aBase, bBase)
    }
    ; =========================
    ; BY + 数字开头
    ; =========================
    aBY := RegExMatch(aBase, "^BY\d")
    bBY := RegExMatch(bBase, "^BY\d")
    if (aBY && !bBY)
        return -1
    if (!aBY && bBY)
        return 1
    if (aBY && bBY)
    {
        n1 := Integer(RegExReplace(aBase, "^BY(\d+).*", "$1"))
        n2 := Integer(RegExReplace(bBase, "^BY(\d+).*", "$1"))
        if (n1 != n2)
            return n1 - n2
        return StrCompare(aBase, bBase)
    }
    ; =========================
    ; 其他文件
    ; =========================
    return StrCompare(aBase, bBase)
}