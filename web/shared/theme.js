/* ===== THEME LOADER ===== */
/* Reads saved theme from localStorage and applies it to <html>. */
/* Must be loaded early (before body renders) to avoid flash. */

(function() {
  var THEME_KEY = 'hjlr_theme';
  var VALID = ['soviet','dark','light','bw','festivus'];

  // Compute Easter Sunday for a given year (Anonymous Gregorian algorithm)
  function computeEaster(year) {
    var a = year % 19;
    var b = Math.floor(year / 100);
    var c = year % 100;
    var d = Math.floor(b / 4);
    var e = b % 4;
    var f = Math.floor((b + 8) / 25);
    var g = Math.floor((b - f + 1) / 3);
    var h = (19 * a + b - d - g + 15) % 30;
    var i = Math.floor(c / 4);
    var k = c % 4;
    var l = (32 + 2 * e + 2 * i - h - k) % 7;
    var m = Math.floor((a + 11 * h + 22 * l) / 451);
    var month = Math.floor((h + l - 7 * m + 114) / 31) - 1; // 0-indexed
    var day = ((h + l - 7 * m + 114) % 31) + 1;
    return new Date(year, month, day);
  }

  // Determine which holiday is "next" based on today's date.
  // Returns a holiday id string.
  function getCurrentHoliday() {
    var now = new Date();
    var y = now.getFullYear();
    var m = now.getMonth();   // 0-indexed
    var d = now.getDate();

    var easter = computeEaster(y);
    var easterM = easter.getMonth();
    var easterD = easter.getDate();

    // Date ranges (month is 0-indexed):
    // Christmas:    Dec 1 – Dec 25
    // New Year:     Dec 26 – Jan 6
    // Valentine:    Jan 7 – Feb 18
    // Easter:       Feb 19 – Easter Sunday
    // July 4th:     Easter+1 – Jul 10
    // Halloween:    Jul 11 – Nov 1
    // Thanksgiving: Nov 2 – Nov 30

    // Helper: is today on or before a date?
    function onOrBefore(tm, td) { return m < tm || (m === tm && d <= td); }
    function onOrAfter(tm, td) { return m > tm || (m === tm && d >= td); }

    // New Year: Dec 26 – Jan 6
    if ((m === 11 && d >= 26) || (m === 0 && d <= 6)) return 'newyear';
    // Valentine: Jan 7 – Feb 18
    if (onOrAfter(0, 7) && onOrBefore(1, 18)) return 'valentine';
    // Easter: Feb 19 – Easter Sunday
    if (onOrAfter(1, 19) && onOrBefore(easterM, easterD)) return 'easter';
    // July 4th: Easter+1 – Jul 10
    if ((m > easterM || (m === easterM && d > easterD)) && onOrBefore(6, 10)) return 'july4th';
    // Halloween: Jul 11 – Nov 1
    if (onOrAfter(6, 11) && onOrBefore(10, 1)) return 'halloween';
    // Thanksgiving: Nov 2 – Nov 30
    if (onOrAfter(10, 2) && onOrBefore(10, 30)) return 'thanksgiving';
    // Christmas: Dec 1 – Dec 25
    if (onOrAfter(11, 1) && onOrBefore(11, 25)) return 'christmas';

    // Fallback (shouldn't happen)
    return 'easter';
  }

  // Holiday display names
  var HOLIDAY_NAMES = {
    newyear: "New Year's",
    valentine: "Valentine's Day",
    easter: 'Easter',
    july4th: '4th of July',
    halloween: 'Halloween',
    thanksgiving: 'Thanksgiving',
    christmas: 'Christmas'
  };

  function getTheme() {
    try {
      var t = localStorage.getItem(THEME_KEY);
      if (t && VALID.indexOf(t) !== -1) return t;
    } catch(e) {}
    return 'soviet';
  }

  function resolveThemeAttr(t) {
    if (t === 'festivus') return 'festivus-' + getCurrentHoliday();
    return t;
  }

  function setTheme(t) {
    if (VALID.indexOf(t) === -1) return;
    try { localStorage.setItem(THEME_KEY, t); } catch(e) {}
    document.documentElement.setAttribute('data-theme', resolveThemeAttr(t));
  }

  // ===== BACKGROUND MODE =====
  var BG_KEY = 'hjlr_bgmode';
  var BG_IDX_KEY = 'hjlr_bgidx';
  var BG_VALID = ['colors','gallery'];
  var BG_COUNT = 10; // number of images in backgrounds folder

  function getBgMode() {
    try {
      var m = localStorage.getItem(BG_KEY);
      if (m && BG_VALID.indexOf(m) !== -1) return m;
    } catch(e) {}
    return 'colors';
  }

  function getBgIndex() {
    try {
      var i = parseInt(localStorage.getItem(BG_IDX_KEY), 10);
      if (!isNaN(i) && i >= 0 && i < BG_COUNT) return i;
    } catch(e) {}
    return 0;
  }

  function nextBgIndex() {
    var i = (getBgIndex() + 1) % BG_COUNT;
    try { localStorage.setItem(BG_IDX_KEY, String(i)); } catch(e) {}
    return i;
  }

  function resolveAssetPath() {
    // Detect relative path to shared/assets based on current page location
    var scripts = document.getElementsByTagName('script');
    for (var s = 0; s < scripts.length; s++) {
      var src = scripts[s].src || '';
      var idx = src.indexOf('shared/theme.js');
      if (idx !== -1) {
        return src.substring(0, idx) + 'shared/assets/backgrounds/';
      }
    }
    return '../shared/assets/backgrounds/';
  }

  function applyBgMode(mode) {
    function apply() {
      if (mode === 'gallery') {
        var idx = getBgIndex();
        var base = resolveAssetPath();
        var url = base + 'bg' + (idx + 1) + '.svg';
        document.body.setAttribute('data-bg', 'gallery');
        document.body.style.setProperty('--gallery-bg', 'url("' + url + '")');
      } else {
        document.body.removeAttribute('data-bg');
        document.body.style.removeProperty('--gallery-bg');
      }
    }
    if (document.body) { apply(); }
    else { document.addEventListener('DOMContentLoaded', apply); }
  }

  function setBgMode(mode) {
    if (BG_VALID.indexOf(mode) === -1) return;
    try { localStorage.setItem(BG_KEY, mode); } catch(e) {}
    if (mode === 'gallery') nextBgIndex(); // rotate on each set
    applyBgMode(mode);
  }

  // Apply immediately
  applyBgMode(getBgMode());

  // Apply immediately
  document.documentElement.setAttribute('data-theme', resolveThemeAttr(getTheme()));

  // Expose globally
  window.hjlrGetTheme = getTheme;
  window.hjlrSetTheme = setTheme;
  window.hjlrGetCurrentHoliday = getCurrentHoliday;
  window.hjlrHolidayNames = HOLIDAY_NAMES;
  window.hjlrGetBgMode = getBgMode;
  window.hjlrSetBgMode = setBgMode;
})();
