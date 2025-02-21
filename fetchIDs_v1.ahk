#Persistent
#NoEnv
#SingleInstance Force
SetBatchLines, -1
SetWorkingDir, %A_ScriptDir%

global version = "25.2.8.1"

global loopRunning := true  ; Control whether the loop continues running
global firstUpdate := true  ; Track if it's the first update
global discordName, friendID, instances, openPack, webhook ; 使用者設定
global groupName, apiUrl, dcWebhook ; fetch ids 設定
global statusText, userCountText, instanceCountText, timeText

ReadSettings()  ; Read settings from Settings.ini
ShowWindow()  ; Display the GUI window

SetTimer, AutoUpdate, 60000  ; Execute AutoUpdate every 60,000 ms (1 minute)

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

; 顯示視窗
ShowWindow() {
    global friendID, instances, openPack, statusText, userCountText, instanceCountText, timeText

    Gui, MyGui:New, -AlwaysOnTop +ToolWindow +Resize, 自動更新ids  ; 創建 GUI 視窗
    Gui, MyGui:Font, s10 Bold, Segoe UI  ; 設定字體大小 10，加粗，使用 Segoe UI

    ; 添加標題（標題放在視窗內部，而非標題欄）
    ; status := (userStatus ? "上線" : "離線")
    Gui, MyGui:Add, Text, x10 y10 w280 Center vstatusText, 當前狀態: 更新中...

    ; 添加資訊文字
    Gui, MyGui:Font, s9 Norm, Segoe UI  ; 設定一般字體
    Gui, MyGui:Add, Text, x10 y40 w280 Center, ID: %friendID%
    Gui, MyGui:Add, Text, x10 y60 w280 Center vuserCountText, 在線人數: 更新中...
    Gui, MyGui:Add, Text, x10 y80 w280 Center vinstanceCountText , 小號人數: 更新中...

    ; 檢查 webhook 設定是否正確
    webhookText:= "未正確設定"
    if(webhook == dcWebhook)
        webhookText:= "已正確設定"
    else ; 紅字
        Gui, MyGui:Font, s9 Norm cRed, Segoe UI
    Gui, MyGui:Add, Text, x10 y100 w280 Center, DC Webhook: %webhookText%

    ; 恢復字體顏色
    Gui, MyGui:Font, s9 Norm cBlack, Segoe UI

    ; 添加按鈕（並排顯示）
    Gui, MyGui:Add, Button, x40 y120 w100 h30 gOnOnline, 上線
    Gui, MyGui:Add, Button, x160 y120 w100 h30 gOnOffline, 下線

    Gui, MyGui:Add, Text, x10 y160 w280 Right vtimeText, 最後更新: 更新中...

    ; 顯示 GUI
    Gui, MyGui:Show, AutoSize Center, %groupName% 自動更新ids（請勿關閉）  ; 視窗大小根據內容調整，並置中顯示
    return

    ; 按鈕函式
    OnOnline:
    PostOnlineStatus(true)  ; 發送上線狀態
    return

    OnOffline:
    PostOnlineStatus(false)  ; 發送離線狀態
    return

    GuiClose:
    ExitApp  ; 點擊視窗關閉按鈕時，關閉腳本
    return
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
    global apiUrl, friendID, statusText, userCountText, instanceCountText, timeText
    response := HTTPRequest(apiUrl, "GET")

    if (response) {
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
            GuiControl, MyGui:, statusText, 當前狀態: 上線
        }
        else{
            GuiControl, MyGui:, statusText, 當前狀態: 離線
        }

        GuiControl,MyGui:, userCountText, 在線人數: %onlineUserCount% / %userCount%
        GuiControl,MyGui:, instanceCountText, 小號人數: %onlineInstanceCount% / %instanceCount%
        time := A_Now
        time := SubStr(time, 5, 2) "/" SubStr(time, 7, 2) " " SubStr(time, 9, 2) ":" SubStr(time, 11, 2) ":" SubStr(time, 13, 2)
        GuiControl,MyGui:, timeText, 最後更新: %time%

        Gui, MyGui:Show, AutoSize NA  ; 重新顯示 GUI

        return true  ; Return true on success
    }
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
    IniRead, webhook, Settings.ini, UserSettings, discordWebhookURL, ""
    IniRead, groupName, TeamSettings.ini, TeamSettings, groupName, ""
    IniRead, apiUrl, TeamSettings.ini, TeamSettings, apiUrl, ""
    IniRead, dcWebhook, TeamSettings.ini, TeamSettings, dcWebhook, ""
}

; ===== 發送測試的 POST 請求=====
PostOnlineStatus(status) {
    global friendID, instances, openPack, apiUrl

    ReadSettings()  ; 讀取設定檔

    statusStr := status ? "true" : "false"

    jsonBody := "{""id"":""" friendID """,""instances"":""" instances """,""pack"":""" openPack """,""status"":""" statusStr """,""webhook"":""" webhook """,""version"":""" version """}"
    response := HTTPRequest(apiUrl, "POST", jsonBody)

    if (response) {
        MsgBox, 發送成功!
        GetOnlineIDs()  ; 更新 ids.txt
    } else {
        MsgBox, 發送失敗!
    }
}
