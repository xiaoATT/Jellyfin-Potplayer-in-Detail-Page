Add-Type -Assembly System.Web
$path=$args[0]
echo $path
$path=$path -replace "jellypotplayer://" , ""
$path=$path -replace "\+", "%2B"   # 先把 + 替换为 %2B
$path=$path -replace "/" , "\"
$path= [System.Web.HttpUtility]::UrlDecode($path)
echo $path
Start-Process -FilePath "C:\Program Files\DAUM\PotPlayer\PotPlayerMini64.exe" -ArgumentList $path
exit