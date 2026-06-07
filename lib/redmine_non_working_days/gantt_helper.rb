# frozen_string_literal: true

module RedmineNonWorkingDays
  module GanttHelper
    # 標準休業日（曜日）と、本プラグインが管理する非稼働日（祝日・個別設定・定期ルール）を
    # 合わせて判定する。Gantt表示用。
    def non_working_day?(date)
      week_days = Array(Setting.non_working_week_days).map(&:to_i)
      return true if week_days.include?(date.cwday)

      RedmineNonWorkingDays::Cache.non_working_date?(date)
    end
  end
end
