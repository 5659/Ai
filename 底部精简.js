(function () {
  'use strict';
  const css = `
    nav a[href="/explore"],
    nav a[href="/i/grok"],
    nav a[href="/notifications"],
    nav a[href="/messages"] {
      display: none !important;
    }
  `;
  const style = document.createElement('style');
  style.textContent = css;
  (document.head || document.documentElement).appendChild(style);
})();
