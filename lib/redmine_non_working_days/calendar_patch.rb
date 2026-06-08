# frozen_string_literal: true

module RedmineNonWorkingDays
  module CalendarPatch
    # 標準の曜日判定（non_working_week_days）に加えて、本プラグインが管理する
    # 非稼働日（祝日・個別設定・定期ルール）にも標準と同じ nwday クラスを付与する
    def day_css_classes(day)
      css = super
      css << ' nwday' if !css.include?('nwday') && RedmineNonWorkingDays::Cache.non_working_date?(day)
      css
    end
  end
end
