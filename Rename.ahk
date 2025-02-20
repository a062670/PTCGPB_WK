#NoEnv
#Persistent

Gui, Add, Text,, 請輸入名稱（最多9個字母/數字）：
Gui, Add, Edit, vUserID w200
Gui, Add, Button, gGenerate, 生成 usernames.txt
Gui, Show,, ID 生成器
Return

Generate:
Gui, Submit, NoHide
if (StrLen(UserID) > 9) {
    MsgBox, 名稱不能超過9個字母/數字！
    Return
}
if !FileExist("Scripts") {
    FileCreateDir, Scripts
}
FilePath := "usernames.txt"
FileDelete, %FilePath%
Loop, 5000
{
    FileAppend, %UserID%%A_Index%`n, %FilePath%
}
Gui, Destroy
MsgBox, usernames.txt 已成功生成！
ExitApp
