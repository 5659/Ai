// ==UserScript==
// @name         X 隐藏广告和黄推（BetterX Lite）
// @namespace    betterx-lite
// @version      1.0
// @description  精简版：隐藏 X 的广告帖与黄推/引流机器人（原生 JS，兼容 Alook）
// @match        *://x.com/*
// @match        *://twitter.com/*
// @grant        none
// @run-at       document-end
// ==/UserScript==

(function () {
  'use strict';

  /* ========== 可自行修改的配置 ========== */
  const HIDE_ADS = true;        // 隐藏广告/推广帖
  const HIDE_PORN = true;       // 隐藏黄推
  const THRESHOLD = 2;          // 黄推判定分数，越小越激进
  const WHITELIST = [           // 白名单（用户名，不带 @，小写）
    // 'someone',
  ];
  // 强特征词，每命中一个 +2
  const STRONG = [
    '约炮', '裸聊', '空降', '楼凤', '上门服务', '同城约', '福利姬',
    'onlyfans', '做爱', '援交', '包夜', '外围', '私密群', '炮友', '无码'
  ];
  // 弱特征词，每命中一个 +1
  const WEAK = [
    '福利', '色色', '同城', '加v', '加微', '看我主页', '点我主页',
    '内射', '寂寞', '小姐姐', '资源', '18+', '🔞'
  ];
  const EMOJI = ['🍑', '💦', '👅', '🍆', '🥵', '😘', '🔥']; // 出现 3 个及以上 +1
  const AD_LABELS = ['ad', 'promoted', '广告', '推广', '推廣', 'プロモーション', '広告'];
  /* ==================================== */

  function getText(el) {
    return el ? (el.innerText || el.textContent || '') : '';
  }

  function isAd(article) {
    // 广告帖底部会有一个小标签（Ad / 广告 / 推广）
    const spans = article.querySelectorAll('span');
    for (const s of spans) {
      if (s.children.length) continue;
      const t = (s.textContent || '').trim().toLowerCase();
      if (t && t.length <= 12 && AD_LABELS.includes(t)) return true;
    }
    return false;
  }

  function getHandle(article) {
    const a = article.querySelector('[data-testid="User-Name"] a[href^="/"]');
    if (!a) return '';
    return (a.getAttribute('href') || '').replace('/', '').split('/')[0].toLowerCase();
  }

  function pornScore(article) {
    const name = getText(article.querySelector('[data-testid="User-Name"]'));
    const body = getText(article.querySelector('[data-testid="tweetText"]'));
    const all = (name + ' ' + body).toLowerCase();
    let score = 0;
    for (const k of STRONG) if (all.includes(k.toLowerCase())) score += 2;
    for (const k of WEAK) if (all.includes(k.toLowerCase())) score += 1;
    let emojiCount = 0;
    for (const e of EMOJI) emojiCount += all.split(e).length - 1;
    if (emojiCount >= 3) score += 1;
    if (/t\.me\/|telegram\.me\//i.test(all)) score += 1;
    return score;
  }

  function hide(article) {
    const cell = article.closest('[data-testid="cellInnerDiv"]') || article;
    cell.style.display = 'none';
  }

  function scan() {
    const articles = document.querySelectorAll('article[data-testid="tweet"]:not([data-bxl])');
    articles.forEach((article) => {
      article.setAttribute('data-bxl', '1');
      const handle = getHandle(article);
      if (handle && WHITELIST.includes(handle)) return;

      if (HIDE_ADS && isAd(article)) { hide(article); return; }
      if (HIDE_PORN && pornScore(article) >= THRESHOLD) hide(article);
    });

    // 侧栏/时间线中的推广块
    if (HIDE_ADS) {
      document.querySelectorAll('[data-testid="placementTracking"]:not([data-bxl])').forEach((el) => {
        el.setAttribute('data-bxl', '1');
        const cell = el.closest('[data-testid="cellInnerDiv"]');
        if (cell) cell.style.display = 'none';
      });
    }
  }

  let timer = null;
  function schedule() {
    if (timer) return;
    timer = setTimeout(() => {
      timer = null;
      try { scan(); } catch (e) { /* 忽略 */ }
    }, 200);
  }

  new MutationObserver(schedule).observe(document.documentElement, {
    childList: true,
    subtree: true
  });
  schedule();
})();
