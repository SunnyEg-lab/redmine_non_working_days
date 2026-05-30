module RedmineNonWorkingDays
  module DateCalculationPatch
    FILE_PATH = Rails.root.join(
      'plugins',
      'redmine_non_working_days',
      'config',
      'non_working_days.txt'
    )

    HOLIDAYS =
      if File.exist?(FILE_PATH)
        File.readlines(FILE_PATH, chomp: true).map do |line|
          next if line.strip.empty? || line.start_with?('#')
          Date.parse(line.split.first)
        rescue
          nil
        end.compact.freeze
      else
        [].freeze
      end

    private

    def working_day_with_holiday?(date)
      return false if non_working_week_days.include?(date.cwday)
      return false if HOLIDAYS.include?(date)
      true
    end

    def working_days(from, to)
      return 0 if from.nil? || to.nil?
      days = 0
      date = from
      while date <= to
        days += 1 if working_day_with_holiday?(date)
        date += 1
      end
      days
    end

    def add_working_days(date, working_days)
      return date if working_days <= 0
      d = date
      count = 0
      while count < working_days
        d += 1
        count += 1 if working_day_with_holiday?(d)
      end
      d
    end

    def next_working_date(date)
      d = date
      d += 1 until working_day_with_holiday?(d)
      d
    end
  end
end
