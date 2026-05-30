/* ============================================================
   EasyGantt 専用パッチ
   Redmine 本体のガントには影響しない
   Ruby 側で生成した非稼働日一覧を使って is_working_day を拡張
============================================================ */

(function() {
  if (!window.gantt || !gantt._working_time_helper) {
    console.log("[NonWorkingDays] EasyGantt not ready");
    return;
  }

  console.log("[NonWorkingDays] EasyGantt patch active");

  var original = gantt._working_time_helper.is_working_day;

  gantt._working_time_helper.is_working_day = function(date) {
    date = this.toMoment(date);
    var key = date.format("YYYY-MM-DD");

    // Ruby 側から渡された非稼働日（祝日・独自休日・非稼働曜日）
    if (window.ysy &&
        ysy.settings &&
        ysy.settings.customNonWorkingDays &&
        ysy.settings.customNonWorkingDays.indexOf(key) !== -1) {
      return false;
    }

    // 既存ロジック（曜日・hours）
    return original.call(this, date);
  };
})();

