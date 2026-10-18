(function () {
  'use strict';

  function getStatusUrl(article) {
    const t = article.querySelector('a[href*="/status/"] time');
    const a = t && t.closest('a');
    return a ? a.href : '';
  }

  document.addEventListener('click', function (e) {
    const target = e.target;
    if (!target || !target.closest) return;

    const article = target.closest('article[data-testid="tweet"]');
    if (!article) return;

    // 点到链接、按钮、图片、视频等时保持原有行为
    if (target.closest('a, button, [role="button"], [role="link"], [role="group"], video, [data-testid="tweetPhoto"], [data-testid="User-Name"], input, textarea')) return;

    const url = getStatusUrl(article);
    if (!url) return;

    // 已经在这条推文的页面上就不再重复打开
    try {
      if (new URL(url).pathname === location.pathname) return;
    } catch (err) { return; }

    e.preventDefault();
    e.stopPropagation();
    window.open(url, '_blank');
  }, true);
})();
