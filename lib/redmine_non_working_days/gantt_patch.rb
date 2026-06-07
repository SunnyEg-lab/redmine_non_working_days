# frozen_string_literal: true

module RedmineNonWorkingDays
  module GanttPatch
    include RedmineNonWorkingDays::GanttHelper

    # ============================================================
    # 画像ガント（PNG/PDF）の生成
    # 元の to_image をほぼそのままコピーし、
    # 「Days details」内の non_working_week_days 判定だけ
    # non_working_day?（祝日・個別設定・定期ルールを含む）に差し替えている
    # ============================================================
    def to_image(format='PNG')
      date_to = (@date_from >> @months) - 1
      show_weeks = @zoom > 1
      show_days = @zoom > 2
      subject_width = 400
      header_height = 18
      # width of one day in pixels
      zoom = @zoom * 2
      g_width = (@date_to - @date_from + 1) * zoom
      g_height = 20 * number_of_rows + 30
      headers_height = (show_weeks ? 2 * header_height : header_height)
      height = g_height + headers_height
      # TODO: Remove rmagick_font_path in a later version
      unless Redmine::Configuration['rmagick_font_path'].nil?
        Rails.logger.warn(
          'rmagick_font_path option is deprecated. Use minimagick_font_path instead.'
        )
      end
      font_path =
        Redmine::Configuration['minimagick_font_path'].presence ||
          Redmine::Configuration['rmagick_font_path'].presence
      img = MiniMagick::Image.create(".#{format}")
      if Redmine::Configuration['imagemagick_convert_command'].present?
        MiniMagick.cli_path = File.dirname(Redmine::Configuration['imagemagick_convert_command'])
      end
      MiniMagick.convert do |gc|
        gc.size('%dx%d' % [subject_width + g_width + 1, height])
        gc.xc('white')
        gc.font(font_path) if font_path.present?
        # Subjects
        gc.stroke('transparent')
        subjects(:image => gc, :top => (headers_height + 20), :indent => 4, :format => :image)
        # Months headers
        month_f = @date_from
        left = subject_width
        @months.times do
          width = ((month_f >> 1) - month_f) * zoom
          gc.fill('white')
          gc.stroke('grey')
          gc.strokewidth(1)
          gc.draw('rectangle %d,%d %d,%d' % [
            left, 0, left + width, height
          ])
          gc.fill('black')
          gc.stroke('transparent')
          gc.strokewidth(1)
          gc.draw('text %d,%d %s' % [
            left.round + 8, 14, magick_text("#{month_f.year}-#{month_f.month}")
          ])
          left = left + width
          month_f = month_f >> 1
        end
        # Weeks headers
        if show_weeks
          left = subject_width
          height = header_height
          if @date_from.cwday == 1
            # date_from is monday
            week_f = date_from
          else
            # find next monday after date_from
            week_f = @date_from + (7 - @date_from.cwday + 1)
            width = (7 - @date_from.cwday + 1) * zoom
            gc.fill('white')
            gc.stroke('grey')
            gc.strokewidth(1)
            gc.draw('rectangle %d,%d %d,%d' % [
              left, header_height, left + width, 2 * header_height + g_height - 1
            ])
            left = left + width
          end
          while week_f <= date_to
            width = (week_f + 6 <= date_to) ? 7 * zoom : (date_to - week_f + 1) * zoom
            gc.fill('white')
            gc.stroke('grey')
            gc.strokewidth(1)
            gc.draw('rectangle %d,%d %d,%d' % [
              left.round, header_height, left.round + width, 2 * header_height + g_height - 1
            ])
            gc.fill('black')
            gc.stroke('transparent')
            gc.strokewidth(1)
            gc.draw('text %d,%d %s' % [
              left.round + 2, header_height + 14, magick_text(week_f.cweek.to_s)
            ])
            left = left + width
            week_f = week_f + 7
          end
        end
        # Days details (non-working days in grey)
        if show_days
          left = subject_width
          height = g_height + header_height - 1
          (@date_from..date_to).each do |g_date|
            width =  zoom
            # ★ ここだけ差し替え：週末判定 → 非稼働日判定（祝日・個別設定・定期ルールを含む）
            gc.fill(non_working_day?(g_date) ? '#eee' : 'white')
            gc.stroke('#ddd')
            gc.strokewidth(1)
            gc.draw('rectangle %d,%d %d,%d' % [
              left, 2 * header_height, left + width, 2 * header_height + g_height - 1
            ])
            left = left + width
          end
        end
        # border
        gc.fill('transparent')
        gc.stroke('grey')
        gc.strokewidth(1)
        gc.draw('rectangle %d,%d %d,%d' % [
          0, 0, subject_width + g_width, headers_height
        ])
        gc.stroke('black')
        gc.draw('rectangle %d,%d %d,%d' % [
          0, 0, subject_width + g_width, g_height + headers_height - 1
        ])
        # content
        top = headers_height + 20
        gc.stroke('transparent')
        lines(:image => gc, :top => top, :zoom => zoom,
              :subject_width => subject_width, :format => :image)
        # today red line
        if User.current.today >= @date_from and User.current.today <= date_to
          gc.stroke('red')
          x = (User.current.today - @date_from + 1) * zoom + subject_width
          gc.draw('line %g,%g %g,%g' % [
            x, headers_height, x, headers_height + g_height - 1
          ])
        end
        gc << img.path
      end
      img.to_blob
    ensure
      img.destroy! if img
    end if Object.const_defined?(:MiniMagick)

    # EasyGantt 等の JS 連携用：表示期間内の非稼働日を YYYY-MM-DD 文字列で返す
    def non_working_dates_in_range
      return [] unless date_from && date_to

      (date_from..date_to).select { |d| non_working_day?(d) }.map(&:to_s)
    end
  end
end
