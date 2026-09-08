# frozen_string_literal: true

module RedmineNonWorkingDays
  # 日本の「国民の祝日に関する法律」に基づき、祝日取得結果を補正・補完する。
  #
  # Nager.Date API の日本データには2種類の問題がある。
  #   A. 日曜と重なった祝日を振替日へ移動して1件だけ返し、法定日が結果から消える
  #      （例: 2026年は 05-06 を「憲法記念日」として返し、法定日の 05-03 を返さない）
  #   B. 移動処理が働かない年があり、その場合は振替休日が完全に欠落する
  #      （例: 2024-09-23、2027-03-22）。国民の休日も返さない（例: 2026-09-22）
  #
  # 日本は法定日も祝日のまま残したうえで振替休日が加わる（休みは2日）が、
  # 英米は振替日のみが法定休日（1日）であり、APIの返し方は英米には適合する。
  # 制度が国ごとに異なるため、本モジュールは日本にのみ適用する。
  #
  # DB・HTTPに依存しない純粋なロジックとして実装し、単体で検証できるようにしている。
  module JapaneseHolidays
    COUNTRY_CODE = 'JP'

    # 振替休日（法第3条第2項）の施行日。1973-04-12 の改正法から。
    SUBSTITUTE_START_DATE = Date.new(1973, 4, 12)
    # 2007-01-01 施行の改正で「翌日」から「その日後で最も近い祝日でない日」へ変更。
    # それ以前は翌日が祝日の場合、振替休日は発生しない。
    SUBSTITUTE_NEAREST_FROM = Date.new(2007, 1, 1)
    # 国民の休日（法第3条第3項）の施行日。1985-12-27 の改正法から。
    CITIZENS_START_DATE = Date.new(1985, 12, 27)

    # 法定日が固定されている祝日の対応表（名称 => [[月, 日, 適用開始年, 適用終了年], ...]）。
    # 適用終了年 nil は現行制度。同じ名称で法定日が変わったものは複数行持つ。
    #
    # ハッピーマンデー（成人の日・海の日・敬老の日・スポーツの日の現行制度）は
    # 必ず月曜となり日曜と重ならないため、現行期間は対象外。
    # 春分の日・秋分の日は日付が変動するうえ、APIが移動させない実測結果のため対象外。
    FIXED_DATE_HOLIDAYS = {
      '元日'         => [[1, 1, 1949, nil]],
      '成人の日'     => [[1, 15, 1949, 1999]],   # 2000年からハッピーマンデー
      '建国記念の日' => [[2, 11, 1967, nil]],
      '天皇誕生日'   => [[4, 29, 1949, 1988],    # 昭和
                        [12, 23, 1989, 2018],   # 平成
                        [2, 23, 2020, nil]],    # 令和（2019年は該当なし）
      'みどりの日'   => [[4, 29, 1989, 2006],
                        [5, 4, 2007, nil]],
      '昭和の日'     => [[4, 29, 2007, nil]],
      '憲法記念日'   => [[5, 3, 1949, nil]],
      'こどもの日'   => [[5, 5, 1949, nil]],
      '海の日'       => [[7, 20, 1996, 2002]],   # 2003年からハッピーマンデー
      '山の日'       => [[8, 11, 2016, nil]],
      '敬老の日'     => [[9, 15, 1966, 2002]],   # 2003年からハッピーマンデー
      '体育の日'     => [[10, 10, 1966, 1999]],  # 2000年からハッピーマンデー
      '文化の日'     => [[11, 3, 1948, nil]],
      '勤労感謝の日' => [[11, 23, 1948, nil]],
    }.freeze

    # generate() への入力を「第2条の国民の祝日」に限定するための除外マーカー。
    # 現行制度上、第2条の国民の祝日の名称にはこれらの文字列を含まない。APIが
    # 将来これらを独立エントリとして返すようになった場合、除外せずに渡すと
    # 「休日」を「祝日」と誤認し、次の振替休日判定を1日後ろへ余分にずらして
    # しまう（レビュー指摘: MR!59 #1121）。
    #
    # 部分一致のため、特別法上の祝日（例: 2019年即位関連の「休日（祝日扱い）」）
    # のように名称に「休日」を含む祝日が入力に来ると誤って除外されうる。ただし
    # そうした特別法上の祝日はこのモジュールの対応表・対応年に含めておらず
    # （README「Japanese Holidays」節に明記）、現行のNager.Date APIも該当する
    # 年・名称を返さないため（1980〜2035年で実測、該当0件）、現時点で誤爆は
    # 発生しない（レビュー指摘: MR!59 #1133）。
    DAY_OFF_TITLE_MARKERS = ['休日', 'Substitute', 'Observed'].freeze

    module_function

    def applicable?(country_code)
      country_code.to_s.upcase == COUNTRY_CODE
    end

    # 取得した祝日を補正・補完して、登録すべき祝日・休日の一覧を返す。
    #
    # @param entries [Array<Hash>] [{ date: Date, title: String }, ...]（API取得結果）
    # @param year    [Integer] 取得対象年
    # @return [Array<Hash>] [{ date: Date, title: String }, ...] を日付順で返す
    def complete(entries, year)
      corrected = correct_legal_dates(entries, year)

      # 第2条の国民の祝日のみを generate() に渡す。既に「休日」であるエントリ
      # （振替休日・国民の休日相当）を祝日として渡さない。
      statutory_dates = corrected.reject { |e| day_off_title?(e[:title]) }.map { |e| e[:date] }

      # 生成分は対象年内に限定する。取込は対象年のholidayを全削除して置き換える方式のため、
      # 年をまたいで登録すると再取込時に洗い替えされず残骸になる。
      generated = generate(statutory_dates).select { |e| e[:date].year == year }

      # correct_legal_dates は複数エントリを同じ法定日へ書き戻すことがある
      # （例: APIが法定日・観測日を同名で2件返した場合）。日付+名称が重複した
      # 行を1件に畳む（レビュー指摘: MR!59 #1120）。DBにユニーク制約が無いため
      # ここで畳んでおかないと create! がサイレントに重複登録してしまう。
      (corrected + generated).uniq { |e| [e[:date], e[:title]] }.sort_by { |e| [e[:date], e[:title]] }
    end

    def day_off_title?(title)
      DAY_OFF_TITLE_MARKERS.any? { |marker| title.to_s.include?(marker) }
    end

    # 問題A対策: APIが振替日へ移動して返した祝日を法定日へ戻す。
    #
    # 誤補正を避けるため、以下をすべて満たす場合のみ日付を戻す。
    #   - 名称が対応表に一致する
    #   - 取得年が当該祝日の適用年の範囲内である
    #   - 法定日が日曜である（日本では日曜と重なった場合しか移動が起きない）
    #   - APIの日付が法定日より後である（前倒し移動する国のロジックを誤適用しない）
    # 一致しない場合は何もしないため、対応表が古くても現状より悪化しない。
    def correct_legal_dates(entries, year)
      entries.map do |entry|
        legal = legal_date(entry[:title], year)
        next entry if legal.nil?
        next entry unless legal.sunday? && entry[:date] > legal

        entry.merge(date: legal)
      end
    end

    def legal_date(title, year)
      rules = FIXED_DATE_HOLIDAYS[title]
      return nil if rules.nil?

      rule = rules.find { |(_m, _d, from, to)| year >= from && (to.nil? || year <= to) }
      return nil if rule.nil?

      Date.new(year, rule[0], rule[1])
    end

    # 問題B対策: 祝日から振替休日・国民の休日を導出する。
    #
    # @param holiday_dates [Enumerable<Date>] 祝日（振替休日等を含まない）の日付
    def generate(holiday_dates)
      holidays    = Set.new(Array(holiday_dates))
      substitutes = substitute_dates(holidays)
      citizens    = citizens_dates(holidays, substitutes)

      (substitutes.map { |d| { date: d, title: substitute_title } } +
       citizens.map    { |d| { date: d, title: citizens_title } }).sort_by { |h| h[:date] }
    end

    # 振替休日（法第3条第2項）:
    # 祝日が日曜に当たるとき、その日後で最も近い「祝日でない日」を休日とする。
    def substitute_dates(holidays)
      result = []
      holidays.select { |d| d.sunday? && d >= SUBSTITUTE_START_DATE }.sort.each do |sunday|
        candidate = sunday + 1
        if sunday >= SUBSTITUTE_NEAREST_FROM
          candidate += 1 while holidays.include?(candidate) || result.include?(candidate)
        else
          # 改正前は翌日固定。翌日が祝日なら振替休日は発生しない。
          next if holidays.include?(candidate)
        end
        result << candidate
      end
      result
    end

    # 国民の休日（法第3条第3項）:
    # 前日・翌日がいずれも祝日である日を休日とする。
    # ただし日曜日・振替休日に当たる日は除く。
    def citizens_dates(holidays, substitute_dates)
      return [] if holidays.empty?

      excluded = holidays | Set.new(substitute_dates)
      (holidays.min..holidays.max).select do |date|
        date >= CITIZENS_START_DATE &&
          !excluded.include?(date) &&
          !date.sunday? &&
          holidays.include?(date - 1) &&
          holidays.include?(date + 1)
      end
    end

    # タイトルはRedmineのデフォルト言語で決定する（Cache.weekday_title と同様）。
    # 取得操作をしたユーザーの個人設定でDBに保存される名称が変わらないようにするため。
    def substitute_title
      translate(:label_non_working_day_substitute_holiday, '振替休日')
    end

    def citizens_title
      translate(:label_non_working_day_citizens_holiday, '国民の休日')
    end

    def translate(key, fallback)
      ::I18n.t(key, locale: ::Setting.default_language, default: fallback)
    end
  end
end
