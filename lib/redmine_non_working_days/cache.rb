# frozen_string_literal: true

module RedmineNonWorkingDays
  module Cache
    CACHE_KEY_DATES = 'non_working_days/dates_set'
    CACHE_KEY_RULES = 'non_working_days/rules'

    module_function

    def non_working_date?(date)
      dates_set.include?(date) || rules.any? { |r| r.matches?(date) }
    end

    def dates_set
      Rails.cache.fetch(CACHE_KEY_DATES) do
        Set.new(NonWorkingDayEntry.pluck(:date))
      end
    end

    def rules
      Rails.cache.fetch(CACHE_KEY_RULES) do
        NonWorkingDayRule.all.to_a
      end
    end

    def invalidate!
      Rails.cache.delete(CACHE_KEY_DATES)
      Rails.cache.delete(CACHE_KEY_RULES)
    end

    # 指定範囲の非稼働日を展開して返す（外部API用）
    def expand_for_range(from, to, kinds: nil)
      results = []

      entries = NonWorkingDayEntry.for_range(from, to)
      entries = entries.where(kind: kinds) if kinds.present?
      entries.each do |e|
        results << { date: e.date, title: e.title, kind: e.kind, country_code: e.country_code }
      end

      unless kinds.present? && !kinds.include?('custom_recurring')
        rules.each do |rule|
          range_start = [from, rule.start_date].compact.max
          range_end   = [to,   rule.end_date  ].compact.min
          next if range_start > range_end

          (range_start..range_end).each do |date|
            results << { date: date, title: rule.title, kind: 'custom_recurring', country_code: nil } if rule.matches?(date)
          end
        end
      end

      results.sort_by { |r| r[:date] }
    end
  end
end
