module RedmineNonWorkingDays
  module NonWorkingDayHelper
    def non_working_day?(date)
      # 設定された非稼働曜日
      week_days =
        Array(Setting.non_working_week_days).map(&:to_i)
      return true if week_days.include?(date.cwday)

      # 祝日（プラグインの HOLIDAYS）
      if defined?(RedmineNonWorkingDays::DateCalculationPatch::HOLIDAYS)
        return true if RedmineNonWorkingDays::DateCalculationPatch::HOLIDAYS.include?(date)
      end

      false
    end
  end
end
