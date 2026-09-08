/* redmine_non_working_days - calendar UI */
/* global NWD */

var NWD = (function() {
  'use strict';

  var cfg = {};

  // cwday (1=Mon..7=Sun) → 0-based Sun index (0=Sun..6=Sat)
  function cwdayToIndex(cwday) { return cwday % 7; }

  function isNonWorkingWeekDay(date) {
    // Redmine cwday: 1=Mon..7=Sun
    return cfg.nonWorkingWeekDays.indexOf(date.getDay() === 0 ? 7 : date.getDay()) !== -1;
  }

  function dateKey(date) {
    var y = date.getFullYear();
    var m = String(date.getMonth() + 1).padStart(2, '0');
    var d = String(date.getDate()).padStart(2, '0');
    return y + '-' + m + '-' + d;
  }

  // 優先順位: holiday > custom_fixed > custom_recurring > standard
  function dayClass(date) {
    var key     = dateKey(date);
    var entries = cfg.nwdData[key] || [];
    var kinds   = entries.map(function(e) { return e.kind; });
    if (kinds.indexOf('holiday')          !== -1) return 'nwd-holiday';
    if (kinds.indexOf('custom_fixed')     !== -1) return 'nwd-custom-fixed';
    if (kinds.indexOf('custom_recurring') !== -1) return 'nwd-custom-recurring';
    if (isNonWorkingWeekDay(date))                return 'nwd-standard';
    return '';
  }

  // ---- 月カレンダー描画 ----
  function renderMonthCalendar(year, month) {
    var title = cfg.labels.weekdays[0].slice(0, 3);  // dummy, use month name
    var monthNames = ['January','February','March','April','May','June',
                      'July','August','September','October','November','December'];
    // ロケールに応じた月名は labels に持たせてもよいが、ここはシンプルに年-月表示
    document.getElementById('nwd-month-title').textContent = year + '-' + String(month).padStart(2, '0');

    var first   = new Date(year, month - 1, 1);
    var last    = new Date(year, month, 0);
    var startWd = first.getDay(); // 0=Sun

    var html = '<table class="nwd-month-table"><thead><tr>';
    cfg.labels.weekdays.forEach(function(w) {
      html += '<th>' + w + '</th>';
    });
    html += '</tr></thead><tbody><tr>';

    for (var i = 0; i < startWd; i++) html += '<td></td>';

    var col = startWd;
    for (var d = 1; d <= last.getDate(); d++) {
      var date    = new Date(year, month - 1, d);
      var key     = dateKey(date);
      var cls     = dayClass(date);
      var entries = cfg.nwdData[key] || [];
      var MAX_SHOW = 3;

      html += '<td class="' + cls + '">';
      html += '<div class="nwd-day-num">' + d + '</div>';
      html += '<div class="nwd-day-entries">';
      entries.slice(0, MAX_SHOW).forEach(function(e) {
        html += '<div class="nwd-day-entry nwd-' + e.kind.replace('_', '-') + '">' +
                  escHtml(e.title) + '</div>';
      });
      if (entries.length > MAX_SHOW) {
        html += '<span class="nwd-more-link" data-date="' + key + '">+' +
                (entries.length - MAX_SHOW) + '</span>';
      }
      html += '</div></td>';

      col++;
      if (col === 7 && d < last.getDate()) { html += '</tr><tr>'; col = 0; }
    }
    while (col > 0 && col < 7) { html += '<td></td>'; col++; }
    html += '</tr></tbody></table>';

    document.getElementById('nwd-month-body').innerHTML = html;

    // +N クリック → ポップアップ
    document.querySelectorAll('.nwd-more-link').forEach(function(el) {
      el.addEventListener('click', function() {
        var dateStr  = this.getAttribute('data-date');
        var allItems = cfg.nwdData[dateStr] || [];
        var inner    = '<strong>' + dateStr + '</strong><ul>';
        allItems.forEach(function(e) {
          inner += '<li class="nwd-' + e.kind.replace('_', '-') + '">' + escHtml(e.title) + '</li>';
        });
        inner += '</ul>';
        document.getElementById('nwd-popup-body').innerHTML = inner;
        document.getElementById('nwd-overlay').style.display = 'block';
        document.getElementById('nwd-popup').style.display   = 'block';
      });
    });
  }

  function escHtml(str) {
    return str.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
  }

  function closePopup() {
    document.getElementById('nwd-popup').style.display   = 'none';
    document.getElementById('nwd-overlay').style.display = 'none';
  }

  // ---- public ----
  return {
    init: function(options) {
      cfg = options;
      var year  = cfg.year;
      var month = cfg.month;

      // ポップアップ DOM 生成
      var overlay = document.createElement('div');
      overlay.id  = 'nwd-overlay';
      overlay.addEventListener('click', closePopup);
      document.body.appendChild(overlay);

      var popup = document.createElement('div');
      popup.id  = 'nwd-popup';
      popup.innerHTML = '<span id="nwd-popup-close">&times;</span>' +
                        '<div id="nwd-popup-body"></div>';
      document.body.appendChild(popup);
      document.getElementById('nwd-popup-close').addEventListener('click', closePopup);

      // 月カレンダー初期表示
      renderMonthCalendar(year, month);

      // 年カレンダーの月クリック
      document.querySelectorAll('.nwd-month-link').forEach(function(el) {
        el.addEventListener('click', function(e) {
          e.preventDefault();
          month = parseInt(this.getAttribute('data-month'), 10);
          renderMonthCalendar(year, month);
          document.getElementById('nwd-month-calendar').scrollIntoView({ behavior: 'smooth' });
        });
      });

      // 月カレンダーナビ
      document.getElementById('nwd-month-prev').addEventListener('click', function() {
        month--;
        if (month < 1)  { month = 12; }
        renderMonthCalendar(year, month);
      });
      document.getElementById('nwd-month-next').addEventListener('click', function() {
        month++;
        if (month > 12) { month = 1; }
        renderMonthCalendar(year, month);
      });
      document.getElementById('nwd-month-today').addEventListener('click', function() {
        var now = new Date();
        year  = now.getFullYear();
        month = now.getMonth() + 1;
        renderMonthCalendar(year, month);
      });
    }
  };
})();
