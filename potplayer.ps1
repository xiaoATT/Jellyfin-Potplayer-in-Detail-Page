Add-Type -Assembly System.Web
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll", SetLastError=true)]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern IntPtr SendMessage(IntPtr hWnd, int Msg, int wParam, int lParam);
}
"@

# 时间转换
function Convert-SecondsToHMS($seconds) {
    $ts = [TimeSpan]::FromSeconds($seconds)
    return "{0:00}:{1:00}:{2:00}" -f $ts.Hours, $ts.Minutes, $ts.Seconds
}


# 调试信息输出开关
$debug = $false
$jellyfin_url = "http://192.168.1.2:8096"
$potplayer_path = "C:\Program Files\DAUM\PotPlayer\PotPlayerMini64.exe"

$path=$args[0]
if($debug){
    Write-Host "[DEBUG] 原始 path 参数: $path"
}

# 地址转码
# 去协议头
$path = $path -replace "^jellypotplayer://+", ""
# 特殊情形处理
$path = $path -replace "\+", "%2B"
# / 替换为 \
$path = $path -replace "/", "\"
# URL 解码
$path = [System.Web.HttpUtility]::UrlDecode($path)
if ($path -notmatch "^\\\\") {
    $path = "\\" + $path.TrimStart('\')
}
if($debug) {
    Write-Host "[DEBUG] 转码后地址: $path"
}


# 先分割 path 和参数（只按第一个问号分割）
$parts = $path -split '\?', 2
$purePath = $parts[0]
$paramStr = if ($parts.Count -gt 1) { $parts[1] } else { "" }

# 解析参数
$paramDict = @{}
if ($paramStr) {
    foreach ($pair in $paramStr -split '&') {
        if ($pair -match "^(.*?)=(.*)$") {
            $k = $Matches[1]
            $v = $Matches[2]
            $paramDict[$k] = $v
        }
    }
}
if($debug){
    Write-Host "[DEBUG] paramStr: $paramStr"
    Write-Host "[DEBUG] paramDict: $(ConvertTo-Json $paramDict)"
}
$item_id = $paramDict['id']
$session_id = $paramDict['sessionId']
$cur_time = $paramDict['curTime']
$device = $paramDict['device']
$deviceId = $paramDict['deviceId']
$token = $paramDict['Token']
$version = $paramDict['version']
$path = $purePath

# cur_time 单独处理
if ($cur_time) { $cur_time = [math]::Floor([double]::Parse($cur_time) / 10000000) }

# 调试：输出参数
if ($debug) {
    Write-Host "[DEBUG] 参数输出---------------"
    Write-Host "[DEBUG] 地址: $path"
    Write-Host "[DEBUG] 视频ID: $item_id"
    Write-Host "[DEBUG] 会话ID: $session_id"
    Write-Host "[DEBUG] 当前时间: $cur_time"
    Write-Host "[DEBUG] 设备: $device"
    Write-Host "[DEBUG] 设备ID: $deviceId"
    Write-Host "[DEBUG] Token: $token"
    Write-Host "[DEBUG] 版本: $version"
}

# 启动 PotPlayer 并获取进程对象，指定播放时间
$seek_arg = ""
if ($cur_time -gt 0) {
    $seek_time = Convert-SecondsToHMS $cur_time
    $seek_arg = "/seek=$seek_time"
}
$all_args = if ($seek_arg) { "$seek_arg `"$path`"" } else { "`"$path`"" }
if($debug) {
    Write-Host "[DEBUG] 启动 PotPlayer 及参数---------------"
    Write-Host "[DEBUG] $all_args"
}
Write-Host "即将打开文件 $all_args"
$process = Start-Process -FilePath $potplayer_path -ArgumentList $all_args -PassThru

# 等待主窗口出现（最多等5秒）
$hWnd = 0
for ($i=0; $i -lt 10; $i++) {
    Start-Sleep -Milliseconds 500
    $process.Refresh()
    $hWnd = $process.MainWindowHandle
    if ($hWnd -ne 0) { break }
}

if ($hWnd -eq 0) {
    Write-Host "未获取到 PotPlayer 主窗口句柄"
    exit 1
}

$WM_USER = 0x400
$GET_CUR_TIME = 0x5004

# 组装headers
$authorization = 'MediaBrowser Client="Jellyfin Web", Device="' + $device + '", DeviceId="' + $deviceId + '", Version="' + $version + '", Token="' + $token + '"'
$headers = @{ 'Authorization' = $authorization }
if($debug) {
    Write-Host "调试信息：请求头部---------------"
    echo $headers
}

# 上报开始播放，并输出请求结果
function Report-PlayPosition($jellyfin_url, $item_id, $play_session_id, $cur_time) {
    $body = @{ 'ItemId' = $item_id; 'PlaySessionId' = $play_session_id }
    try {
        $response = Invoke-WebRequest -Uri "$jellyfin_url/Sessions/Playing" -Headers $headers -Method POST -Body ($body | ConvertTo-Json) -ContentType 'application/json'
        if($debug) {
            Write-Host "开始播放 HTTP 状态码: $($response.StatusCode)"
        }
    } catch {
        Write-Host "上报播放开始失败: $_"
        if ($_.Exception.Response) {
            $errResp = $_.Exception.Response
            Write-Host "错误状态码: $($errResp.StatusCode.value__)"
        }
    }
}


function Report-PlayStopped($jellyfin_url, $item_id, $play_session_id, $cur_time) {
    $ticks = [math]::Floor($cur_time * 10000000)
    $body = @{ 'PositionTicks' = $ticks; 'ItemId' = $item_id; 'PlaySessionId' = $play_session_id }
    try {
        $response = Invoke-WebRequest -Uri "$jellyfin_url/Sessions/Playing/Stopped" -Headers $headers -Method POST -Body ($body | ConvertTo-Json) -ContentType 'application/json'
        if($debug) {
            Write-Host "上报播放停止 HTTP 状态码: $($response.StatusCode)"
        }
    } catch {
        Write-Host "上报播放停止失败: $_"
        if ($_.Exception.Response) {
            $errResp = $_.Exception.Response
            Write-Host "错误状态码: $($errResp.StatusCode.value__)"
        }
    }
}

# 上报开始播放
if ($item_id -and $session_id) {
    Report-PlayPosition $jellyfin_url $item_id $session_id $cur_time
}

# 循环获取播放进度，直到 PotPlayer 关闭
while (!$process.HasExited) {
    $curTimeMs = [Win32]::SendMessage($hWnd, $WM_USER, $GET_CUR_TIME, 1)
    # 时间等于0时不赋值
    if ($curTimeMs -ne 0) {
        $curTimeSec = [math]::Floor($curTimeMs / 1000)
    }
    if($debug) {
        Write-Host "调试信息：当前播放进度: $curTimeSec 秒"
    }
    Start-Sleep -Seconds 1
    $process.Refresh()
}

# PotPlayer 关闭时上报时间
if ($item_id -and $session_id) {
    Report-PlayStopped $jellyfin_url $item_id $session_id $curTimeSec
}

Write-Host "PotPlayer 已关闭，脚本退出"
exit