#NoEnv
#SingleInstance, Force
SendMode, Input
SetBatchLines, -1
SetWorkingDir, %A_ScriptDir%

scriptFolder := A_ScriptDir
zipPath := A_Temp . "\update.zip"
wkBranch := "WK_cn_cloud"
zipDownloadURL := "https://github.com/a062670/PTCGPB_WK/archive/refs/heads/" . wkBranch .  ".zip"
update()
Return

update(){
    global zipPath, zipDownloadURL, scriptFolder

    if(!FileExist("PTCGPB.ahk")){
        MsgBox, 請在PTCGPB的資料夾下執行！
        ExitApp
    }
    MsgBox, 開始更新
    URLDownloadToFile, %zipDownloadURL% , %zipPath%
    if (ErrorLevel) {
        MsgBox, 更新失敗！錯誤碼：%ErrorLevel%
        return
    } else {
        MsgBox, 下載完成，準備解壓縮

        ; Create a temporary folder for extraction
        tempExtractPath := A_Temp "\PTCGPB_Temp"
        tempSavePath := A_Temp "\PTCGPB_Save_Temp"

        FileRemoveDir, %tempExtractPath%, 1
        FileRemoveDir, %tempSavePath%, 1

        FileCreateDir, %tempExtractPath%
        FileCreateDir, %tempSavePath%

        ; Extract the ZIP file into the temporary folder
        RunWait, powershell -Command "Expand-Archive -Path '%zipPath%' -DestinationPath '%tempExtractPath%' -Force",, Hide

        ; Check if extraction was successful
        if !FileExist(tempExtractPath)
        {
            MsgBox, 解壓縮更新檔失敗.
            return
        }

        ; Get the first subfolder in the extracted folder
        Loop, Files, %tempExtractPath%\*, D
        {
            extractedFolder := A_LoopFileFullPath
            break
        }

        ; Check if a subfolder was found and move its contents recursively to the script folder
        if (extractedFolder)
        {
            BackupFile(scriptFolder, tempSavePath) ; 把不要動到的檔案輩分
            MoveFilesRecursively(extractedFolder, scriptFolder)
            RestoreFile(scriptFolder, tempSavePath) ; 把備份檔案還原
            ; Clean up the temporary extraction folder
            FileRemoveDir, %tempExtractPath%, 1
            FileRemoveDir, %tempSavePath%, 1
            MsgBox, 更新成功
            ExitApp
        }
        else
        {
            MsgBox, 找不到解壓縮後的檔案.
            return
        }
    }
}

InArray(needle, haystack){
    For Key, value in haystack {
        if(needle == value){
            return true
        }
    }
    return false
}

BackupFile(scriptFolder, tempFolder){
    needBackupFile := ["ids.txt", "discord.txt", "usernames.txt", "Settings.ini", "TeamSettings.ini", "vip_ids.txt"]
    Loop, Files, % scriptFolder . "\*"
    {
        relativePath := SubStr(A_LoopFileFullPath, StrLen(scriptFolder) + 2)
        if (InArray(relativePath, needBackupFile) && FileExist(A_LoopFileFullPath)) { ; 如果有找到檔案 則移到暫存資料夾
            FileCopy, % A_LoopFileFullPath, % tempFolder, 1
        }
        FileDelete, % A_LoopFileFullPath
    }
}

RestoreFile(scriptFolder, tempFolder){
    Loop, Files, % tempFolder . "\*"
    {
        relativePath := SubStr(A_LoopFileFullPath, StrLen(tempFolder) + 2)
        FileMove, % A_LoopFileFullPath, % scriptFolder, 1
    }
}

MoveFilesRecursively(srcFolder, destFolder) {
    ; MsgBox, %srcFolder%
    ; MsgBox, %destFolder%
    ; Loop through all files and subfolders in the source folder
    Loop, Files, % srcFolder . "\*", R
    {
        ; Get the relative path of the file/folder from the srcFolder
        relativePath := SubStr(A_LoopFileFullPath, StrLen(srcFolder) + 2)

        ; Create the corresponding destination path
        destPath := destFolder . "\" . relativePath

        ; If it's a directory, create it in the destination folder
        if (A_LoopIsDir)
        {
            ; Ensure the directory exists, if not, create it
            FileCreateDir, % destPath
        }
        else
        {
            checkArray := ["ids.txt", "discord.txt", "usernames.txt", "Settings.ini", "TeamSettings.ini", "vip_ids.txt", "update.ahk"]
            if (InArray(relativePath, checkArray) && FileExist(destPath)) {
                continue
            }
            ; If it's a file, move it to the destination folder
            ; Ensure the directory exists before moving the file
            FileCreateDir, % SubStr(destPath, 1, InStr(destPath, "\", 0, 0) - 1)
            FileMove, % A_LoopFileFullPath, % destPath, 1
        }
    }
}

