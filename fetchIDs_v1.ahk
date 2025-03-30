#Persistent
#NoEnv
#SingleInstance Force

SetBatchLines, -1
SetWorkingDir, %A_ScriptDir%

global version = "25.3.14.1"
global wkBranch = "WK_cn_cloud"

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
    url := "https://raw.githubusercontent.com/a062670/PTCGPB_WK/" . wkBranch . "/fetchIDs_v1.ahk"
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
    url := "https://raw.githubusercontent.com/a062670/PTCGPB_WK/" . wkBranch . "/fetchIDs_v1.ahk"
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
        parsed := JSON.load(response)

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
    versionStr := Format("{}({})({})", PTCGPBVersion, version, wkBranch)
    jsonBody := "{""id"":""" friendID """,""instances"":""" instances """,""pack"":""" openPack """,""status"":""" statusStr """,""webhook"":""" webhook """,""version"":""" versionStr """}"
    response := HTTPRequest(apiUrl, "POST", jsonBody)

    if (response) {
        GuiControl, , statusText, 當前狀態: 確認目前狀態...
        GetOnlineIDs()  ; 更新 ids.txt
    } else {
        GuiControl, , statusText, 當前狀態: 更新失敗
    }
}

/**
 * Lib: JSON.ahk
 *     JSON lib for AutoHotkey.
 * Version:
 *     v2.1.3 [updated 04/18/2016 (MM/DD/YYYY)]
 * License:
 *     WTFPL [http://wtfpl.net/]
 * Requirements:
 *     Latest version of AutoHotkey (v1.1+ or v2.0-a+)
 * Installation:
 *     Use #Include JSON.ahk or copy into a function library folder and then
 *     use #Include <JSON>
 * Links:
 *     GitHub:     - https://github.com/cocobelgica/AutoHotkey-JSON
 *     Forum Topic - http://goo.gl/r0zI8t
 *     Email:      - cocobelgica <at> gmail <dot> com
 */

/**
 * Class: JSON
 *     The JSON object contains methods for parsing JSON and converting values
 *     to JSON. Callable - NO; Instantiable - YES; Subclassable - YES;
 *     Nestable(via #Include) - NO.
 * Methods:
 *     Load() - see relevant documentation before method definition header
 *     Dump() - see relevant documentation before method definition header
 */
class JSON
{
    /**
     * Method: Load
     *     Parses a JSON string into an AHK value
     * Syntax:
     *     value := JSON.Load( text [, reviver ] )
     * Parameter(s):
     *     value      [retval] - parsed value
     *     text    [in, ByRef] - JSON formatted string
     *     reviver   [in, opt] - function object, similar to JavaScript's
     *                           JSON.parse() 'reviver' parameter
     */
    class Load extends JSON.Functor
    {
        Call(self, ByRef text, reviver:="")
        {
            this.rev := IsObject(reviver) ? reviver : false
            ; Object keys(and array indices) are temporarily stored in arrays so that
            ; we can enumerate them in the order they appear in the document/text instead
            ; of alphabetically. Skip if no reviver function is specified.
            this.keys := this.rev ? {} : false

            static quot := Chr(34), bashq := "\" . quot
                , json_value := quot . "{[01234567890-tfn"
                , json_value_or_array_closing := quot . "{[]01234567890-tfn"
                , object_key_or_object_closing := quot . "}"

            key := ""
            is_key := false
            root := {}
            stack := [root]
            next := json_value
            pos := 0

            while ((ch := SubStr(text, ++pos, 1)) != "") {
                if InStr(" `t`r`n", ch)
                    continue
                if !InStr(next, ch, 1)
                    this.ParseError(next, text, pos)

                holder := stack[1]
                is_array := holder.IsArray

                if InStr(",:", ch) {
                    next := (is_key := !is_array && ch == ",") ? quot : json_value

                } else if InStr("}]", ch) {
                    ObjRemoveAt(stack, 1)
                    next := stack[1]==root ? "" : stack[1].IsArray ? ",]" : ",}"

                } else {
                    if InStr("{[", ch) {
                        ; Check if Array() is overridden and if its return value has
                        ; the 'IsArray' property. If so, Array() will be called normally,
                        ; otherwise, use a custom base object for arrays
                        static json_array := Func("Array").IsBuiltIn || ![].IsArray ? {IsArray: true} : 0

                          ; sacrifice readability for minor(actually negligible) performance gain
                          (ch == "{")
                              ? ( is_key := true
                                , value := {}
                                , next := object_key_or_object_closing )
                              ; ch == "["
                              : ( value := json_array ? new json_array : []
                                , next := json_value_or_array_closing )

                          ObjInsertAt(stack, 1, value)

                          if (this.keys)
                              this.keys[value] := []

                      } else {
                          if (ch == quot) {
                              i := pos
                              while (i := InStr(text, quot,, i+1)) {
                                  value := StrReplace(SubStr(text, pos+1, i-pos-1), "\\", "\u005c")

                                  static tail := A_AhkVersion<"2" ? 0 : -1
                                  if (SubStr(value, tail) != "\")
                                      break
                              }

                              if (!i)
                                  this.ParseError("'", text, pos)

                                value := StrReplace(value,  "\/",  "/")
                              , value := StrReplace(value, bashq, quot)
                              , value := StrReplace(value,  "\b", "`b")
                              , value := StrReplace(value,  "\f", "`f")
                              , value := StrReplace(value,  "\n", "`n")
                              , value := StrReplace(value,  "\r", "`r")
                              , value := StrReplace(value,  "\t", "`t")

                              pos := i ; update pos

                              i := 0
                              while (i := InStr(value, "\",, i+1)) {
                                  if !(SubStr(value, i+1, 1) == "u")
                                      this.ParseError("\", text, pos - StrLen(SubStr(value, i+1)))

                                  uffff := Abs("0x" . SubStr(value, i+2, 4))
                                  if (A_IsUnicode || uffff < 0x100)
                                      value := SubStr(value, 1, i-1) . Chr(uffff) . SubStr(value, i+6)
                              }

                              if (is_key) {
                                  key := value, next := ":"
                                  continue
                              }

                          } else {
                              value := SubStr(text, pos, i := RegExMatch(text, "[\]\},\s]|$",, pos)-pos)

                              static number := "number", integer :="integer"
                              if value is %number%
                              {
                                  if value is %integer%
                                      value += 0
                              }
                              else if (value == "true" || value == "false")
                                  value := %value% + 0
                              else if (value == "null")
                                  value := ""
                              else
                                  ; we can do more here to pinpoint the actual culprit
                                  ; but that's just too much extra work.
                                  this.ParseError(next, text, pos, i)

                              pos += i-1
                          }

                          next := holder==root ? "" : is_array ? ",]" : ",}"
                      } ; If InStr("{[", ch) { ... } else

                      is_array? key := ObjPush(holder, value) : holder[key] := value

                      if (this.keys && this.keys.HasKey(holder))
                          this.keys[holder].Push(key)
                  }

              } ; while ( ... )

              return this.rev ? this.Walk(root, "") : root[""]
          }

          ParseError(expect, ByRef text, pos, len:=1)
          {
              static quot := Chr(34), qurly := quot . "}"

              line := StrSplit(SubStr(text, 1, pos), "`n", "`r").Length()
              col := pos - InStr(text, "`n",, -(StrLen(text)-pos+1))
              msg := Format("{1}`n`nLine:`t{2}`nCol:`t{3}`nChar:`t{4}"
              ,     (expect == "")     ? "Extra data"
                  : (expect == "'")    ? "Unterminated string starting at"
                  : (expect == "\")    ? "Invalid \escape"
                  : (expect == ":")    ? "Expecting ':' delimiter"
                  : (expect == quot)   ? "Expecting object key enclosed in double quotes"
                  : (expect == qurly)  ? "Expecting object key enclosed in double quotes or object closing '}'"
                  : (expect == ",}")   ? "Expecting ',' delimiter or object closing '}'"
                  : (expect == ",]")   ? "Expecting ',' delimiter or array closing ']'"
                  : InStr(expect, "]") ? "Expecting JSON value or array closing ']'"
                  :                      "Expecting JSON value(string, number, true, false, null, object or array)"
              , line, col, pos)

              static offset := A_AhkVersion<"2" ? -3 : -4
              throw Exception(msg, offset, SubStr(text, pos, len))
          }

          Walk(holder, key)
          {
              value := holder[key]
              if IsObject(value) {
                  for i, k in this.keys[value] {
                      ; check if ObjHasKey(value, k) ??
                      v := this.Walk(value, k)
                      if (v != JSON.Undefined)
                          value[k] := v
                      else
                          ObjDelete(value, k)
                  }
              }

              return this.rev.Call(holder, key, value)
          }
      }

                        /**
                         * Method: Dump
                         *     Converts an AHK value into a JSON string
                         * Syntax:
                         *     str := JSON.Dump( value [, replacer, space ] )
                         * Parameter(s):
                         *     str        [retval] - JSON representation of an AHK value
                         *     value          [in] - any value(object, string, number)
                         *     replacer  [in, opt] - function object, similar to JavaScript's
                         *                           JSON.stringify() 'replacer' parameter
                         *     space     [in, opt] - similar to JavaScript's JSON.stringify()
                         *                           'space' parameter
                         */
      class Dump extends JSON.Functor
      {
          Call(self, value, replacer:="", space:="")
          {
              this.rep := IsObject(replacer) ? replacer : ""

              this.gap := ""
              if (space) {
                  static integer := "integer"
                  if space is %integer%
                      Loop, % ((n := Abs(space))>10 ? 10 : n)
                          this.gap .= " "
                  else
                      this.gap := SubStr(space, 1, 10)

                  this.indent := "`n"
              }

              return this.Str({"": value}, "")
          }

          Str(holder, key)
          {
              value := holder[key]

              if (this.rep)
                  value := this.rep.Call(holder, key, ObjHasKey(holder, key) ? value : JSON.Undefined)

              if IsObject(value) {
                  ; Check object type, skip serialization for other object types such as
                  ; ComObject, Func, BoundFunc, FileObject, RegExMatchObject, Property, etc.
                  static type := A_AhkVersion<"2" ? "" : Func("Type")
                  if (type ? type.Call(value) == "Object" : ObjGetCapacity(value) != "") {
                      if (this.gap) {
                          stepback := this.indent
                          this.indent .= this.gap
                      }

                      is_array := value.IsArray
                      ; Array() is not overridden, rollback to old method of
                      ; identifying array-like objects. Due to the use of a for-loop
                      ; sparse arrays such as '[1,,3]' are detected as objects({}).
                      if (!is_array) {
                          for i in value
                              is_array := i == A_Index
                          until !is_array
                      }

                      str := ""
                      if (is_array) {
                          Loop, % value.Length() {
                              if (this.gap)
                                  str .= this.indent

                              v := this.Str(value, A_Index)
                              str .= (v != "") ? v . "," : "null,"
                          }
                      } else {
                          colon := this.gap ? ": " : ":"
                          for k in value {
                              v := this.Str(value, k)
                              if (v != "") {
                                  if (this.gap)
                                      str .= this.indent

                                  str .= this.Quote(k) . colon . v . ","
                              }
                          }
                      }

                      if (str != "") {
                          str := RTrim(str, ",")
                          if (this.gap)
                              str .= stepback
                      }

                      if (this.gap)
                          this.indent := stepback

                      return is_array ? "[" . str . "]" : "{" . str . "}"
                  }

              } else ; is_number ? value : "value"
                  return ObjGetCapacity([value], 1)=="" ? value : this.Quote(value)
          }

          Quote(string)
          {
              static quot := Chr(34), bashq := "\" . quot

              if (string != "") {
                    string := StrReplace(string,  "\",  "\\")
                  ; , string := StrReplace(string,  "/",  "\/") ; optional in ECMAScript
                  , string := StrReplace(string, quot, bashq)
                  , string := StrReplace(string, "`b",  "\b")
                  , string := StrReplace(string, "`f",  "\f")
                  , string := StrReplace(string, "`n",  "\n")
                  , string := StrReplace(string, "`r",  "\r")
                  , string := StrReplace(string, "`t",  "\t")

                  static rx_escapable := A_AhkVersion<"2" ? "O)[^\x20-\x7e]" : "[^\x20-\x7e]"
                  while RegExMatch(string, rx_escapable, m)
                      string := StrReplace(string, m.Value, Format("\u{1:04x}", Ord(m.Value)))
              }

              return quot . string . quot
          }
      }

                        /**
                         * Property: Undefined
                         *     Proxy for 'undefined' type
                         * Syntax:
                         *     undefined := JSON.Undefined
                         * Remarks:
                         *     For use with reviver and replacer functions since AutoHotkey does not
                         *     have an 'undefined' type. Returning blank("") or 0 won't work since these
                         *     can't be distnguished from actual JSON values. This leaves us with objects.
                         *     Replacer() - the caller may return a non-serializable AHK objects such as
                         *     ComObject, Func, BoundFunc, FileObject, RegExMatchObject, and Property to
                         *     mimic the behavior of returning 'undefined' in JavaScript but for the sake
                         *     of code readability and convenience, it's better to do 'return JSON.Undefined'.
                         *     Internally, the property returns a ComObject with the variant type of VT_EMPTY.
                         */
      Undefined[]
      {
          get {
              static empty := {}, vt_empty := ComObject(0, &empty, 1)
              return vt_empty
          }
      }

      class Functor
      {
          __Call(method, ByRef arg, args*)
          {
              ; When casting to Call(), use a new instance of the "function object"
              ; so as to avoid directly storing the properties(used across sub-methods)
              ; into the "function object" itself.
              if IsObject(method)
                  return (new this).Call(method, arg, args*)
              else if (method == "")
                  return (new this).Call(arg, args*)
          }
      }
  }
