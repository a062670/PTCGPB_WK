#Persistent
#NoEnv
#SingleInstance Force

SetBatchLines, -1
SetWorkingDir, %A_ScriptDir%

global version = "25.3.5.5"

global loopRunning := true  ; Control whether the loop continues running
global firstUpdate := true  ; Track if it's the first update
global discordName, friendID, instances, openPack, webhook, hbWebhook ; 使用者設定
global groupName, apiUrl, dcWebhook, teamHbWebhook ; fetch ids 設定
global statusText, userCountText, instanceCountText, timeText, loadingStatus, PTCGPBVersion

CheckUsername()
CheckTeamSettings()
ReadSettings()

Gui, Font, s10 Bold, Segoe UI  ; 設定字體大小 10，加粗，使用 Segoe UI
Gui, Add, Text, w280 x10 vstatusText, 當前狀態: --
SetNormalFont()
Gui, Add, Text, w280 , ID: %friendID%
Gui, Add, Text, w280 vuserCountText, 在線人數: -- / --
Gui, Add, Text, w280 vinstanceCountText , 小號人數: -- / --

; 檢查 webhook 設定是否正確
webhookText:= ""
if (webhook != dcWebhook)
    webhookText:= webhookText . " 一般"
if (!!teamHbWebhook && hbWebhook != teamHbWebhook)
    webhookText:= webhookText . " 心跳"
if (webhookText != "") {
    webhookText:= "設定錯誤:" . webhookText
    Gui, Font, s9 Norm cRed, Segoe UI
} else {
    webhookText:= "設定正確"
}
Gui, Add, Text, w280, Webhook: %webhookText%

SetNormalFont()

; 添加按鈕（並排顯示）
Gui, Add, Button, w100 h30 gOnOnline, 上線
Gui, Add, Button, x+10 w100 h30 gOnOffline, 下線

Gui, Add, Text, w280 x10 vLoadingStatus, IDs 更新狀態: 無
Gui, Add, Text, w280 x10 vtimeText, IDs 最後更新: 更新中...
; Gui, Add, Button, x10 gAutoUpdate, 手動更新 ; 測試用

Gui, Add, Text, w280 x10, PTCGPB版本: %PTCGPBVersion%
Gui, Add, Text, x10 w280 vVersion, fetchIDs版本: %version%
Gui, Add, Button, x10 vUpdateButton gUpdateToLatestVersion, 檢查新版本

title := groupName . "自動更新ids"
guiWidth = 356
guiHeight = 435
positionX := A_ScreenWidth - guiWidth
positionY := A_ScreenHeight - guiHeight - 90
Gui, Show, w280 x%positionX% y%positionY%, %title%

Gosub, AutoUpdate ; 一開始先執行一次
SetTimer, AutoUpdate, 60000  ; Execute AutoUpdate every 60,000 ms (1 minute)
SetTimer, CheckForUpdates, 1000
Return

GuiClose:
ExitApp

CheckForUpdates:
    SetTimer, CheckForUpdates, Off
    CheckForUpdate()
Return

UpdateToLatestVersion:
    CheckForUpdate(true)
Return

CheckTeamSettings(){
    if(!FileExist("TeamSettings.ini")){
        MsgBox, 請先下載TeamSettings.ini放進資料夾
        ExitApp
    }
}

HttpGet(url) {
    try{
        http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        http.Open("GET", url, false)
        http.Send()
        return http.ResponseText
    } catch e {
        return 0
    }
}

FineRemoteVersion(content){
    Loop, Parse, content, `n
    {
        pos := InStr(A_LoopField, "global version =")
        if(pos){
            RegExMatch(A_LoopField, """(.*?)""", match)
            return match1
        }
    }
    return ""
}

VersionCompare(v1, v2) {
    ; 從PTCGPB搬來
    ; Remove non-numeric characters (like 'alpha', 'beta')
    cleanV1 := RegExReplace(v1, "[^\d.]")
    cleanV2 := RegExReplace(v2, "[^\d.]")

    v1Parts := StrSplit(cleanV1, ".")
    v2Parts := StrSplit(cleanV2, ".")

    Loop, % Max(v1Parts.MaxIndex(), v2Parts.MaxIndex()) {
        num1 := v1Parts[A_Index] ? v1Parts[A_Index] : 0
        num2 := v2Parts[A_Index] ? v2Parts[A_Index] : 0
        if (num1 > num2)
            return 1
        if (num1 < num2)
            return -1
    }

    ; If versions are numerically equal, check if one is an alpha version
    isV1Alpha := InStr(v1, "alpha") || InStr(v1, "beta")
    isV2Alpha := InStr(v2, "alpha") || InStr(v2, "beta")

    if (isV1Alpha && !isV2Alpha)
        return -1 ; Non-alpha version is newer
    if (!isV1Alpha && isV2Alpha)
        return 1 ; Alpha version is older

    return 0 ; Versions are equal
}

CheckForUpdate(needAlert = false){
    url := "https://raw.githubusercontent.com/a062670/PTCGPB_WK/WK/fetchIDs_v1.ahk"
    response := HttpGet(url)
    if !response
    {
        if (needAlert){
            MsgBox, 取得檔案失敗
        }
        return
    }
    ; 取得版本
    remoteVersion := FineRemoteVersion(response)
    if (VersionCompare(remoteVersion, version) > 0){
        GuiControl, , version,fetchIDs版本: %version% (有新版本) ; 新版本提示
        if (needAlert){
            MsgBox, 4, 更新提示, 有新版本 %remoteVersion% 是否要更新？
            IfMsgBox, Yes
            {
                UpdateToLatestVersion()
            }
        }
    } else {
        if (needAlert){
            MsgBox, 尚無新版本
        }
    }
}

UpdateToLatestVersion(){
    url := "https://raw.githubusercontent.com/a062670/PTCGPB_WK/WK/fetchIDs_v1.ahk"
    RunWait, curl -o fetchIDs_v1.ahk %url%, , Hide
    if (ErrorLevel = 0) {
        MsgBox, 更新成功！
        Reload
    } else {
        MsgBox, 更新失敗！錯誤碼：%ErrorLevel%
    }
}

RunRename(){
    Run, "Rename.ahk",, Hide, PID
    Process, WaitClose, %PID%  ; 等待該進程結束
    Reload
}

CheckUsername(){
    ; 檢查第一行
    FileReadLine, name, usernames.txt, 1
    if(name == "bulbasaur" || name == "NoName1" || SubStr(name, 0) != 1){
        RunRename()
        return false
    }
    ; 檢查最後一行
    FileReadLine, lastName, usernames.txt, 5000
    if(SubStr(lastName, -3) != 5000){
        RunRename()
        return false
    }
    return true
}

; ===== Automatically fetch Online IDs and write to ids.txt =====
AutoUpdate:
    if (loopRunning) {
        if (GetOnlineIDs()) {
            if (firstUpdate) {
                ShowNotification("IDs Updated", "Successfully updated IDs in ids.txt", true)  ; Sound notification only for the first update
                firstUpdate := false  ; Disable future notifications
            }
        } else {
            ; loopRunning := false  ; Stop the loop if API request fails
            ShowNotification("Auto Update Stopped", "Failed to fetch data. Please check the API.", true)
        }
    }
return

OnOnline:
    PostOnlineStatus(true)  ; 發送上線狀態
return

OnOffline:
    PostOnlineStatus(false)  ; 發送離線狀態
return

SetNormalFont(){
    Gui, Font, s9 Norm cBlack, Segoe UI
}

;fix unicode
FixUnicode(text) {
    VarSetCapacity(buf, StrPut(text, "UTF-16") * 2)
    StrPut(text, &buf, "UTF-16")
    text := StrGet(&buf, "CP950") ; 轉換為 Big5 碼
    return text
}

; ===== Fetch Online IDs and write to file =====
GetOnlineIDs() {
    global apiUrl, friendID, statusText, userCountText, instanceCountText, timeText, loadingStatus
    GuiControl, , loadingStatus, IDs 更新狀態: 正在更新中
    response := HTTPRequest(apiUrl, "GET")
    if (response) {
        GuiControl, , loadingStatus, IDs 更新狀態: 更新完成
        FileDelete, ids.txt  ; Delete old ids.txt

        ; Parse JSON response and extract Online IDs
        parsed := JSON_parse(response)

        ids := ""
        userStatus := false  ; 確保 userStatus 初始為 false，避免遺留舊值

        for index, value in parsed["onlineIDs"]{
            ids .= (index = 1 ? "" : "`n") value  ; 第一個值不加換行，後面的加 `n`

            ; 如果包含自己的id，則設定userStatus為true
            if (value = friendID) {
                userStatus := true
            }
        }

        ; Write result to file
        FileAppend, %ids%, ids.txt

        ; save other data
        userCount := parsed["userCount"]
        onlineUserCount := parsed["onlineUserCount"]
        instanceCount := parsed["instanceCount"]
        onlineInstanceCount := parsed["onlineInstancesCount"]

        ; Update GUI text
        if(userStatus){
            GuiControl, , statusText, 當前狀態: 上線
        }
        else{
            GuiControl, , statusText, 當前狀態: 離線
        }

        GuiControl, , userCountText, 在線人數: %onlineUserCount% / %userCount%
        GuiControl, , instanceCountText, 小號人數: %onlineInstanceCount% / %instanceCount%
        time := A_Now
        time := SubStr(time, 5, 2) "/" SubStr(time, 7, 2) " " SubStr(time, 9, 2) ":" SubStr(time, 11, 2) ":" SubStr(time, 13, 2)
        GuiControl, , timeText, IDs 最後更新: %time%

        ; Gui, Show , NA  ; 重新顯示 GUI

        return true  ; Return true on success
    }
    GuiControl, , loadingStatus, IDs 更新狀態: 更新失敗
    return false  ; Return false on failure
}

; ===== Parse json data =====
JSON_Parse(json) {
    obj := {}
    ParseObject(obj, json)
    return obj
}

ParseObject(obj, json) {
    ; 處理 onlineIDs
    if (RegExMatch(json, """onlineIDs"":\[(.*?)\]", m)) {
        array := []
        ParseArray(array, m1)
        obj["onlineIDs"] := array
        json := RegExReplace(json, """onlineIDs"":\[(.*?)\](,)?")
    }

    ; 處理 userCount
    if (RegExMatch(json, """userCount"":(\d+)", m)) {
        obj["userCount"] := m1
        json := RegExReplace(json, """userCount"":(\d+)(,)?")
    }

    ; 處理 onlineUserCount
    if (RegExMatch(json, """onlineUserCount"":(\d+)", m)) {
        obj["onlineUserCount"] := m1
        json := RegExReplace(json, """onlineUserCount"":(\d+)(,)?")
    }

    ; 處理 instanceCount
    if (RegExMatch(json, """instanceCount"":(\d+)", m)) {
        obj["instanceCount"] := m1
        json := RegExReplace(json, """instanceCount"":(\d+)(,)?")
    }

    ; 處理 onlineInstancesCount
    if (RegExMatch(json, """onlineInstancesCount"":(\d+)", m)) {
        obj["onlineInstancesCount"] := m1
        json := RegExReplace(json, """onlineInstancesCount"":(\d+)(,)?")
    }
}

ParseArray(array, values) {
    Loop, Parse, values, `,
    {
        value := RegExReplace(A_LoopField, "[\s""]")  ; 移除空白與雙引號
        array.Push(value)
    }
}

; ===== Show notification (with optional sound) =====
ShowNotification(title, message, sound := false) {
    if (sound) {
        TrayTip, %title%, %message%, 3, 1  ; Sound notification
    } else {
        ToolTip, %title%`n%message%  ; Silent notification (shown in bottom-right)
        Sleep, 3000  ; Display for 3 seconds
        ToolTip  ; Clear notification
    }
}

; ===== Stop auto update (Ctrl+F3) =====
^F3::
    loopRunning := false
return

; ===== Send HTTP request =====
HTTPRequest(url, method, body:="") {
    whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    whr.Open(method, url, false)
    whr.SetRequestHeader("Content-Type", "application/json")

    try {
        whr.Send(body)
        whr.WaitForResponse()  ; Wait for request completion
        return whr.ResponseText
    } catch e {
        return ""  ; Return empty string on failure
    }
}

; ===== Test hotkeys =====
^F1::GetOnlineIDs()  ; Press Ctrl+F1 to manually fetch Online IDs
return
^F11:: PostOnlineStatus(true)  ; Press Ctrl+F11 to send online status
return
^F12:: PostOnlineStatus(false)  ; Press Ctrl+F12 to send offline status
return

; ===== 讀取設定檔 =====
ReadSettings() {
    IniRead, friendID, Settings.ini, UserSettings, FriendID, 0
    IniRead, instances, Settings.ini, UserSettings, Instances, 0
    IniRead, openPack, Settings.ini, UserSettings, openPack, Default
    IniRead, webhook, Settings.ini, UserSettings, discordWebhookURL, %A_Space%
    IniRead, hbWebhook, Settings.ini, UserSettings, heartBeatWebhookURL, %A_Space%
    IniRead, groupName, TeamSettings.ini, TeamSettings, groupName, %A_Space%
    IniRead, apiUrl, TeamSettings.ini, TeamSettings, apiUrl, %A_Space%
    IniRead, dcWebhook, TeamSettings.ini, TeamSettings, dcWebhook, %A_Space%
    IniRead, teamHbWebhook, TeamSettings.ini, TeamSettings, heartBeatWebhookURL, %A_Space%

    PTCGPBVersion := FindPTCGPBVersion()
}

FindPTCGPBVersion() {
    lineCount := 0
    result := ""
    Loop Read, PTCGPB.ahk
    {
        lineCount++
        if(lineCount > 10){
            break ;只找十行
        }
        pos := InStr(A_LoopReadLine, "localVersion :=")
        if(pos){
            RegExMatch(A_LoopReadLine, """(.*?)""", match)
            result := match1
            break
        }
    }
    return result
}

; ===== 發送測試的 POST 請求=====
PostOnlineStatus(status) {
    global friendID, instances, openPack, apiUrl

    GuiControl, , statusText, 當前狀態: 更新中...
    ReadSettings()  ; 讀取設定檔

    statusStr := status ? "true" : "false"
    versionStr := Format("{}({})", PTCGPBVersion, version)
    jsonBody := "{""id"":""" friendID """,""instances"":""" instances """,""pack"":""" openPack """,""status"":""" statusStr """,""webhook"":""" webhook """,""version"":""" versionStr """}"
    response := HTTPRequest(apiUrl, "POST", jsonBody)

    if (response) {
        GuiControl, , statusText, 當前狀態: 確認目前狀態...
        GetOnlineIDs()  ; 更新 ids.txt
    } else {
        GuiControl, , statusText, 當前狀態: 更新失敗
    }
}
