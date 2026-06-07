# frozen_string_literal: true

class NonWorkingDayRule < ActiveRecord::Base
  RULE_TYPES = %w[monthly_day monthly_last monthly_nth_weekday biweekly].freeze

  serialize :rule_params, coder: JSON

  validates :title,     presence: true
  validates :rule_type, presence: true, inclusion: { in: RULE_TYPES }
  validate  :end_date_after_start_date
  validate  :rule_params_valid

  after_save    { RedmineNonWorkingDays::Cache.invalidate! }
  after_destroy { RedmineNonWorkingDays::Cache.invalidate! }

  # 一覧表示用：ルール設定を人間が読める文字列に変換する（例: "第1金曜日"）
  def description
    params = rule_params.presence || {}

    case rule_type
    when 'monthly_day'
      unit = I18n.t(:label_non_working_day_day_unit)
      days = Array(params['days']).map(&:to_i).sort
      days.map { |d| "#{d}#{unit}" }.join(', ')
    when 'monthly_last'
      I18n.t(:label_rule_type_monthly_last)
    when 'monthly_nth_weekday'
      I18n.t(:label_non_working_day_rule_desc_monthly_nth_weekday,
             nth:     I18n.t("label_nth_#{params['nth']}"),
             weekday: I18n.t("label_weekday_#{params['weekday']}"))
    when 'biweekly'
      I18n.t(:label_non_working_day_rule_desc_biweekly,
             weekday: I18n.t("label_weekday_#{params['weekday']}"))
    else
      ''
    end
  end

  # 指定日付がこのルールに該当するか評価する
  def matches?(date)
    return false if start_date.present? && date < start_date
    return false if end_date.present?   && date > end_date

    case rule_type
    when 'monthly_day'
      days = Array(rule_params['days']).map(&:to_i)
      days.include?(date.day)
    when 'monthly_last'
      date == date.end_of_month
    when 'monthly_nth_weekday'
      nth     = rule_params['nth'].to_i
      weekday = rule_params['weekday'].to_i  # 0=Sun..6=Sat
      date.cwday % 7 == weekday && nth_weekday_of_month(date) == nth
    when 'biweekly'
      weekday = rule_params['weekday'].to_i
      return false unless date.cwday % 7 == weekday

      origin = biweekly_origin(date)
      return false if origin.nil?

      ((date - origin).to_i % 14).zero?
    else
      false
    end
  end

  private

  def nth_weekday_of_month(date)
    first = Date.new(date.year, date.month, 1)
    wday  = date.cwday % 7  # 0=Sun..6=Sat
    first_match = first + ((wday - first.cwday % 7 + 7) % 7)
    ((date - first_match).to_i / 7) + 1
  end

  # start_date から終了日の間で最初に指定曜日が現れる日
  def biweekly_origin(date)
    return nil if start_date.blank?

    weekday = rule_params['weekday'].to_i
    limit   = end_date.presence || date
    d = start_date
    d += 1 while d <= limit && d.cwday % 7 != weekday
    d <= limit ? d : nil
  end

  def end_date_after_start_date
    return unless start_date.present? && end_date.present?

    errors.add(:end_date, :greater_than_start_date) if end_date < start_date
  end

  def rule_params_valid
    params = rule_params.presence || {}
    case rule_type
    when 'monthly_day'
      days = Array(params['days'])
      errors.add(:rule_params, :days_required) if days.empty?
      errors.add(:rule_params, :days_out_of_range) unless days.all? { |d| (1..31).include?(d.to_i) }
    when 'monthly_nth_weekday'
      errors.add(:rule_params, :nth_required)     unless (1..5).include?(params['nth'].to_i)
      errors.add(:rule_params, :weekday_required) unless (0..6).include?(params['weekday'].to_i)
    when 'biweekly'
      errors.add(:rule_params, :weekday_required) unless (0..6).include?(params['weekday'].to_i)
      errors.add(:start_date,  :required_for_biweekly) if start_date.blank?
    end
  end
end
