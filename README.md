

# Jellyfin with Potplayer in Detail Page

本项目基于 [tccoin/Jellyfin-Potplayer](https://github.com/tccoin/Jellyfin-Potplayer) 二次开发，保留Jellyfin原本的播放按键，在Jellyfin的视频的详情页增加按钮使用potplayer播放。同时增加获取当前播放进度和上传新的播放进度的功能

## 特性
- 仅在 Jellyfin 详情页插入 PotPlayer 播放按钮
- 将 Jellyfin 路径自动转换为局域网 UNC 路径，适配 SMB/NAS
  - 路径转换示例：/jellyfin-video/test.mp4  转换为：\\\\192.168.1.2\\nas-video\\test.mp4
- 将注册表url名称修改为 jellypotplayer，避免与原potplayer冲突
- 打开时自动获取当前视频的播放进度，并打开potplayer到当前进度
- 关闭播放器时自动上报播放结束信息。上报和使用的播放信息都是jellyfin-web的客户端。因此会与网页的播放信息同步

## 安装与使用
1. **下载本仓库代码**
2. **配置 potplayer.ps1 路径**
    - 修改 PowerShell 脚本中的 PotPlayer 路径为你本地实际安装路径
    - 在 -replace中根据需要进行修改，默认去掉 jellypotplayer://，并且将 / 转换为windows UNC路径的 \ 格式
3. **注册表协议配置 potplayer.reg**
    - 修改 potplayer.reg 中的路径为你本地实际安装路径，即potplayer.ps1的文件路径
4. **修改脚本文件 userscript.js**
    - 修改 // @include      http://192.168.1.2:8096/web/*   中的地址为你的Jellyfin网页端地址
    - 修改 path.replace('/jellyfin-video/','//192.168.1.2/nas-video/') 中的前后两个路径为你的实际路径。注意如果是smb共享文件夹的话，前面要加两个斜杠//，后续脚本会将/转换为\
5. **双击 potplayer.reg 修改注册表**
6. **安装 Tampermonkey 并新建脚本，复制粘贴 userscript.js内容并保存**
7. **在 Jellyfin 网页端详情页点击 PotPlayer 按钮即可调用本地播放器**

## 其他说明

* 在.reg中的最后 powershell 命令中添加 -NoExit 参数保持窗口打开，便于调试

## 鸣谢
- 本项目基于 [tccoin/Jellyfin-Potplayer](https://github.com/tccoin/Jellyfin-Potplayer) 开发，感谢原作者的开源贡献！

