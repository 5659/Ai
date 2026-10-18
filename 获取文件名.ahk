#SingleInstance Force

files := []

Loop Files, A_WorkingDir "\*.*", "F"
{
    ; 排除当前正在运行的脚本
    if (A_LoopFileFullPath = A_ScriptFullPath)
        continue

    nameNoExt := RegExReplace(A_LoopFileName, "\.[^.]+$")
    files.Push(nameNoExt)
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
    ; 纯数字开头
    aNum := RegExMatch(a, "^\d")
    bNum := RegExMatch(b, "^\d")

    if (aNum && !bNum)
        return -1

    if (!aNum && bNum)
        return 1

    if (aNum && bNum)
    {
        n1 := Integer(RegExReplace(a, "^(\d+).*", "$1"))
        n2 := Integer(RegExReplace(b, "^(\d+).*", "$1"))

        if (n1 != n2)
            return n1 - n2

        return StrCompare(a, b)
    }

    ; BY + 数字开头
    aBY := RegExMatch(a, "^BY\d")
    bBY := RegExMatch(b, "^BY\d")

    if (aBY && !bBY)
        return -1

    if (!aBY && bBY)
        return 1

    if (aBY && bBY)
    {
        n1 := Integer(RegExReplace(a, "^BY(\d+).*", "$1"))
        n2 := Integer(RegExReplace(b, "^BY(\d+).*", "$1"))

        if (n1 != n2)
            return n1 - n2

        return StrCompare(a, b)
    }

    ; 其他文件
    return StrCompare(a, b)
}