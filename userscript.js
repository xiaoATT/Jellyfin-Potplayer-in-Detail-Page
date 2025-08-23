// ==UserScript==
// @name         Jellyfin with Potplayer in Detail Page
// @version      0.1
// @description  play video with Potplayer in Detail Page
// @author       xiaoA
// @include      http://192.168.1.2:8096/web/*
// ==/UserScript==



(function () {
  'use strict';
  let openJellyPotplayer = async (itemid) => {
    let userid = (await ApiClient.getCurrentUser()).Id;
    ApiClient.getItem(userid, itemid).then(r => {
      if (r.Path) {
        console.log(r);
        // let path = r.Path.replace(/\\/g, '/');
        //path = path.replace('D:', 'Z:');
        let path = r.Path;
        // 先替换前缀
        path = path.replace('/jellyfin-video/', '//192.168.1.2/nas-video/');
        // 再把剩下的 / 替换为 \
        path = path.replace(/\\/g, '/');
        console.log(path);
        window.open('jellypotplayer://' + path)
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
