# frozen_string_literal: true

module NonWorkingDaysHelper
  # 年カレンダーのミニマスに付与する CSS クラスを返す（優先順位適用済み）
  def nwd_day_css(date, nwd_set, non_working_week_days)
    entries = nwd_set[date] || []
    kinds   = entries.map { |e| e[:kind] }
    return 'nwd-holiday'          if kinds.include?('holiday')
    return 'nwd-custom-fixed'     if kinds.include?('custom_fixed')
    return 'nwd-custom-recurring' if kinds.include?('custom_recurring')
    return 'nwd-standard'         if non_working_week_days.include?(date.cwday)

    ''
  end
end
