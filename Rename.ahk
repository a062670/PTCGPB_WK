#NoEnv

Gui, Add, Text, x10 y10, 請輸入您的 ID:
Gui, Add, Edit, vUserID x10 y30 w200
Gui, Add, Button, x10 y60 w100 gGenerateFile, 生成 userNames.txt
Gui, Show, w250 h100, ID 生成器
Return

GenerateFile:
    Gui, Submit, NoHide
    UserID := Trim(UserID)
    ; 限制 ID 長度，確保 ID 本身 + 數字不超過 14 個字母
    MaxIDLength := 14 - StrLen("5000")  ; 5000 為最大數字長度
    if (StrLen(UserID) > MaxIDLength) {
        MsgBox, ID 過長，請輸入最多 %MaxIDLength% 個字符。
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
    MsgBox, 生成完成！文件已保存至：`n%FilePath%
    exitScript() ; 關閉腳本
Return

exitScript(){
    ; 為了格式化不會怪怪的
    ExitApp
}

GuiClose:
ExitApp
