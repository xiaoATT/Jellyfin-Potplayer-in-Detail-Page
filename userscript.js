// ==UserScript==
// @name         Jellyfin with Potplayer in Detail Page
// @version      0.3
// @description  play video with Potplayer in Detail Page and upload playback info
// @author       xiaoA
// @include      http://192.168.1.2:8096/web/*
// ==/UserScript==



(function () {
  'use strict';
  let openJellyPotplayer = async (itemid) => {
    let play_sessionid = (await ApiClient.getPlaybackInfo(itemid)).PlaySessionId
    let userid = (await ApiClient.getCurrentUser()).Id;
    let devicename = await ApiClient.deviceName();
    let deviceid = await ApiClient.deviceId();
    let accesstoken = await ApiClient.accessToken();
    let version = await ApiClient.appVersion();
    ApiClient.getItem(userid, itemid).then(r => {
      if (r.Path) {
        console.log(itemid)
        console.log(r);
        let path = r.Path;
        console.log(path);
        // 枚举表：Jellyfin物理路径前缀 => 协议映射前缀
        const pathMap = [
          { from: '/jellyfin-video1', to: '/nas-video1' },
          { from: '/jellyfin-video1', to: '/nas-video2' },
        ];
        // 匹配映射
        let matched = pathMap.find(m => path.startsWith(m.from));
        console.log(matched);
        if (matched) {
          console.log(path);
          // 拼接 //192.168.1.2/ + 映射前缀 + 剩余路径
          path = `//192.168.1.2${matched.to}${path.substring(matched.from.length)}`;
          console.log(path);
        }
        // 再把剩下的 \\ 替换为 /
        path = path.replace(/\\/g, '/');
        // 获取当前播放进度 时间为 s * 10**7
        let curTime = r.UserData.PlaybackPositionTicks;
        console.log(path);
        console.log(itemid);
        console.log(play_sessionid);
        // 打包path,itemid,play_sessionid
        window.open('jellypotplayer://' + path + 
          '?id=' + itemid + 
          '&sessionId=' + play_sessionid + 
          '&curTime=' + curTime + 
          '&device=' + encodeURIComponent(devicename) + 
          '&deviceId=' + deviceid + 
          '&Token=' + accesstoken + 
          '&version=' + version);
      } else {
        ApiClient.getItems(userid, itemid).then(r => openJellyPotplayer(r.Items[0].Id));
      }
    })
  };

  let bindEvent = async () => {
    if (!location.hash.startsWith('#/details')) {
      return;
    }
    // 先移除之前增加的按钮，防止重复添加
    document.querySelectorAll('button[id^="jellypotplayer-custom-btn-"]').forEach(btn => btn.remove());

    // 查找所有的播放按钮
    let buttons = document.querySelectorAll('button.btnPlay.detailButton[data-action="resume"]');
    let customBtnId = 1;
    for (let targetBtn of buttons) {
      // 当button不是新建的button时
      // 在隔壁创建一个新的button，用来调用PotPlayer
      // 可能存在两个按钮，将id自增作为区分
      if (targetBtn && ! targetBtn.id.startsWith('jellypotplayer-')) {
        let customBtn = document.createElement('button');
        customBtn.id = 'jellypotplayer-custom-btn-' + customBtnId++;
        // 使用 PotPlayer 图标 SVG 作为按钮内容
        customBtn.innerHTML = '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" style="vertical-align:middle;"><circle cx="12" cy="12" r="12" fill="#FFD600"/><polygon points="9,7 17,12 9,17" fill="#333"/></svg>';
        customBtn.className = targetBtn.className;
        // 此项值后续会被覆盖，无解
        customBtn.title = '使用potplayer播放';
        customBtn.style.marginLeft = '8px';
        customBtn.addEventListener('click', function(e) {
          e.stopPropagation();
          let itemid = /id=(.*?)&serverId/.exec(window.location.hash)[1];
          openJellyPotplayer(itemid);
        });
        targetBtn.parentElement.insertBefore(customBtn, targetBtn.nextSibling);
      }
    }
    
  };

  // 监听 hashchange页面改动 事件
  // window.addEventListener('hashchange', bindEvent);
  // 监听 viewshow 事件
  window.addEventListener('viewshow', bindEvent);
})();
