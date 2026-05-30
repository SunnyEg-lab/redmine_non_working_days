Rails.logger.info "[GANTT PATCH] gantt_patch.rb loaded"

require_dependency 'redmine/helpers/gantt'

module RedmineNonWorkingDays
  module GanttPatch
    include RedmineNonWorkingDays::NonWorkingDayHelper

    # ============================================================
    # 【Redmine本体向けパッチ】
    # 画像ガント（HTML側）の生成
    # 元の to_image をほぼそのままコピーし、
    # 「Days details」内の non_working_week_days 判定だけ
    # non_working_day? に差し替えている
    # ============================================================
    def to_image(format='PNG')
      Rails.logger.info "[GANTT PATCH] to_image called"
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
        # Days details (week-end in grey)
        if show_days
          left = subject_width
          height = g_height + header_height - 1
          (@date_from..date_to).each do |g_date|
            width =  zoom
            # ★ ここだけ差し替え：週末判定 → 非稼働日判定（祝日含む）
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
  end

  # ============================================================
  # ここから下は EasyGantt 向けの設定
  # Redmine 本体のガント機能とは完全に独立して動く
  # ============================================================

  Rails.logger.info "[GANTT PATCH] EasyGantt patch loaded"

  Rails.application.config.to_prepare do
    # EasyGantt がインストールされていない場合は何もしない
    unless Redmine::Plugin.installed?(:easy_gantt)
      Rails.logger.info "[GANTT PATCH] EasyGantt not installed, skipping JS patch"
      next
    end

    Rails.logger.info "[GANTT PATCH] EasyGantt detected, enabling JS patch"

    # EasyGantt 用 JS を assets に登録
    # （app/assets/javascripts/non_working_days.js を読み込ませる）
    Rails.application.config.assets.precompile += %w[
      non_working_days.js
    ]
  end
end

# Redmine 本体の GanttController にパッチ適用
GanttsController.prepend RedmineNonWorkingDays::GanttPatch
