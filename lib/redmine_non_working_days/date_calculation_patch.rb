# frozen_string_literal: true

module RedmineNonWorkingDays
  module DateCalculationPatch
    def working_day?(date)
      return false if RedmineNonWorkingDays::Cache.non_working_date?(date)

      super
    end

    def add_working_days(date, working_days)
      return date if working_days <= 0

      d     = date
      count = 0
      while count < working_days
        d += 1
        count += 1 if working_day?(d)
      end
      d
    end

    def working_days(from, to)
      return 0 if from.nil? || to.nil?

      count = 0
      (from..to).each { |d| count += 1 if working_day?(d) }
      count
    end
  end
end
