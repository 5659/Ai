(function () {
  'use strict';

  function expand() {
    document
      .querySelectorAll('[data-testid="tweet-text-show-more-link"]:not([data-bx-open])')
      .forEach((el) => {
        el.setAttribute('data-bx-open', '1');
        el.click();
      });
  }

  let timer = null;
  new MutationObserver(() => {
    if (timer) return;
    timer = setTimeout(() => {
      timer = null;
      expand();
    }, 200);
  }).observe(document.documentElement, { childList: true, subtree: true });

  expand();
})();
