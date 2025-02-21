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
    ; 設定文件路徑
    FilePath := A_ScriptDir "\usernames.txt"
    UserList := ""
    Loop, 5000 {
        UserList .= UserID A_Index "`n"
    }
    FileDelete, %FilePath%  ; 刪除舊文件 (如果存在)
    FileAppend, %UserList%, %FilePath%
    Gui, Destroy
    MsgBox, usernames.txt 已成功生成！
ExitApp
