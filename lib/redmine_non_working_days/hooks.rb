# frozen_string_literal: true

module RedmineNonWorkingDays
  class Hooks < Redmine::Hook::ViewListener
    # EasyGantt（easy_gantt プラグイン）が標準で備える祝日機能 ysy.settings.holidays
    # （"YYYY-MM-DD" の配列）に、本プラグインが管理する非稼働日
    # （祝日・個別設定・定期ルール）を追加注入する。
    # easy_gantt 側のファイルは一切変更しない。
    render_on :view_easy_gantt_index_bottom,
              partial: 'redmine_non_working_days/easy_gantt_holidays'
  end
end
