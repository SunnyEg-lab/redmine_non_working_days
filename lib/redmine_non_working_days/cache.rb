# frozen_string_literal: true

module RedmineNonWorkingDays
  module Cache
    CACHE_KEY_DATES = 'non_working_days/dates_set'
    CACHE_KEY_RULES = 'non_working_days/rules'

    # weekdayはプラグインが管理するデータ(NonWorkingDayEntry/NonWorkingDayRule)では
    # なくRedmineコアの設定値なので別枠の定数にする。
    WEEKDAY_KIND = 'weekday'

    # 同一日付が複数種別で重複した場合の並び順(小さいほど優先)。API利用側が
    # 独自にtie-breakしなくても、レスポンス自体が決定的な順序になるようにする。
    KIND_ORDER = {
      'holiday'          => 0,
      'custom_fixed'     => 1,
      'custom_recurring' => 2,
      WEEKDAY_KIND       => 3,
    }.freeze

    module_function

    # プラグイン自身が管理する非稼働日の種別(NonWorkingDayEntry::KINDS + 繰り返しルール)。
    # 定数ではなくメソッドにしているのは、module本体でNonWorkingDayEntryを直接参照すると、
    # プラグイン読み込み順序次第でオートロード未解決のまま評価される懸念があるため
    # (呼び出し時=リクエスト処理時まで評価を遅らせれば安全)。
    def entry_kinds
      @entry_kinds ||= (NonWorkingDayEntry::KINDS + %w[custom_recurring]).freeze
    end

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

    # 指定範囲の非稼働日を展開して返す（外部API用）。
    #
    # kinds省略時はentry_kinds(holiday/custom_fixed/custom_recurring)に加えて
    # WEEKDAY_KIND(Redmineコア標準の曜日設定Setting.non_working_week_days)も含む。
    # weekdayだけを別枠にしているのは、プラグインが管理するデータ(NonWorkingDayEntry/
    # NonWorkingDayRule)ではなくRedmineコアの設定値だから。呼び出し側が明示的に
    # kindsを指定した場合は、その中にweekdayが含まれる時だけ展開する
    # (index画面のようにweekdayを別経路で扱うカレンダー表示との二重描画を避けるため)。
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

      if kinds.blank? || kinds.include?(WEEKDAY_KIND)
        week_days = Setting.non_working_week_days.map(&:to_i)
        if week_days.present?
          (from..to).each do |date|
            next unless week_days.include?(date.cwday)
            results << { date: date, title: weekday_title(date), kind: WEEKDAY_KIND, country_code: nil }
          end
        end
      end

      # dateだけでは同一日付内の順序がRubyのsort_by(安定ソート非保証)に
      # 委ねられ、呼び出しごとに変わり得る。kind優先順+title昇順まで含めて
      # 決定的にする(利用側で個別にtie-breakしなくても済むようにするため)。
      results.sort_by { |r| [r[:date], KIND_ORDER.fetch(r[:kind], 99), r[:title]] }
    end

    # 曜日設定(weekday)のtitle。固有名を持たない設定値なので、Redmine標準の
    # 曜日名(「土曜日」「日曜日」等)を動的に生成する。呼び出しユーザーの
    # ロケールに左右されないよう、明示的にSetting.default_languageを使う
    # (API呼び出しユーザーの個人設定次第でtitleの言語が変わるのを避けるため)。
    def weekday_title(date)
      ::I18n.t('date.day_names', locale: Setting.default_language)[date.wday]
    end
  end
end
