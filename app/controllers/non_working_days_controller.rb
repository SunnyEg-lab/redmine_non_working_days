# frozen_string_literal: true

class NonWorkingDaysController < ApplicationController
  before_action :require_admin, except: [:api_days]
  before_action :require_api_access, only: [:api_days]

  # GET /non_working_days?year=2026
  def index
    @year            = (params[:year] || Date.today.year).to_i
    year_start       = Date.new(@year, 1, 1)
    year_end         = Date.new(@year, 12, 31)
    @holiday_entries = NonWorkingDayEntry.holidays.for_range(year_start, year_end).order(:date)
    @custom_entries  = NonWorkingDayEntry.custom_fixed.for_range(year_start, year_end).order(:date)
    @rules           = NonWorkingDayRule.where(
                         'start_date IS NULL OR start_date <= ?', year_end
                       ).where(
                         'end_date IS NULL OR end_date >= ?', year_start
                       ).order(:title)

    # 当年の全非稼働日を展開（カレンダー表示用）
    from = Date.new(@year, 1, 1)
    to   = Date.new(@year, 12, 31)
    @expanded = RedmineNonWorkingDays::Cache.expand_for_range(from, to)
    @nwd_set  = @expanded.group_by { |d| d[:date] }

    # Redmine標準休業日（曜日）
    @non_working_week_days = Setting.non_working_week_days.map(&:to_i)
  end

  # GET /non_working_days/entries/new
  def new_entry
    default_date    = params[:last_date].present? ? Date.parse(params[:last_date]) : Date.today
    @entry          = NonWorkingDayEntry.new(kind: 'custom_fixed', date: default_date)
    @filter_year    = (params[:year] || Date.today.year).to_i
    @holiday_listed = NonWorkingDayEntry.holidays.for_year(@filter_year).order(:date)
    @custom_listed  = NonWorkingDayEntry.custom_fixed.for_year(@filter_year).order(:date)
    @open_sections  = params[:open].to_s.split(',')
  end

  # POST /non_working_days/entries
  def create_entry
    @entry = NonWorkingDayEntry.new(entry_params)
    if @entry.save
      flash[:notice] = l(:notice_non_working_day_entry_created)
      redirect_to new_non_working_day_entry_path(
        year:      @entry.date.year,
        last_date: @entry.date,
        open:      params[:open_sections]
      )
    else
      @filter_year    = (params[:year] || Date.today.year).to_i
      @holiday_listed = NonWorkingDayEntry.holidays.for_year(@filter_year).order(:date)
      @custom_listed  = NonWorkingDayEntry.custom_fixed.for_year(@filter_year).order(:date)
      @open_sections  = params[:open_sections].to_s.split(',')
      render :new_entry
    end
  end

  # DELETE /non_working_days/entries/:id
  def destroy_entry
    @entry = NonWorkingDayEntry.find(params[:id])
    year   = @entry.date.year
    @entry.destroy
    flash[:notice] = l(:notice_non_working_day_entry_deleted)
    redirect_back(fallback_location: non_working_days_path(year: year))
  end

  # DELETE /non_working_days/entries (bulk)
  def destroy_entries
    ids = bulk_ids
    NonWorkingDayEntry.where(id: ids).destroy_all
    flash[:notice] = l(:notice_non_working_day_entry_deleted)
    redirect_back(fallback_location: non_working_days_path)
  end

  # GET /non_working_days/rules/new
  def new_rule
    @rule = NonWorkingDayRule.new(
      rule_type:  carried_rule_type,
      start_date: carried_date(:start_date),
      end_date:   carried_date(:end_date)
    )
    @listed_rules = NonWorkingDayRule.order(:title)
    @open_sections = params[:open].to_s.split(',')
  end

  # POST /non_working_days/rules
  def create_rule
    @rule = NonWorkingDayRule.new(rule_params_params)
    if @rule.save
      flash[:notice] = l(:notice_non_working_day_rule_created)
      redirect_to new_non_working_day_rule_path(
        open:       params[:open_sections],
        rule_type:  @rule.rule_type,
        start_date: @rule.start_date,
        end_date:   @rule.end_date
      )
    else
      @listed_rules  = NonWorkingDayRule.order(:title)
      @open_sections = params[:open_sections].to_s.split(',')
      render :new_rule
    end
  end

  # DELETE /non_working_days/rules/:id
  def destroy_rule
    @rule = NonWorkingDayRule.find(params[:id])
    @rule.destroy
    flash[:notice] = l(:notice_non_working_day_rule_deleted)
    redirect_back(fallback_location: non_working_days_path)
  end

  # DELETE /non_working_days/rules (bulk)
  def destroy_rules
    ids = bulk_ids
    NonWorkingDayRule.where(id: ids).destroy_all
    flash[:notice] = l(:notice_non_working_day_rule_deleted)
    redirect_back(fallback_location: non_working_days_path)
  end

  # DELETE /non_working_days/destroy_all
  def destroy_all
    NonWorkingDayEntry.destroy_all
    NonWorkingDayRule.destroy_all
    RedmineNonWorkingDays::Cache.invalidate!
    flash[:notice] = l(:notice_non_working_day_all_deleted)
    redirect_to plugin_settings_path(id: 'redmine_non_working_days')
  end

  # GET /non_working_days/holidays/fetch?year=2026
  def fetch_holidays
    @year          = (params[:year] || Date.today.year + 1).to_i
    @nager_base    = Setting.plugin_redmine_non_working_days['nager_api_base'] ||
                     'https://date.nager.at'
    @countries     = fetch_available_countries(@nager_base)
    @country_code  = params[:country_code] || 'JP'
    # 既存チェックはフォーム送信後（import_holidays）で行う
  end

  # POST /non_working_days/holidays/import
  def import_holidays
    year         = params[:year].to_i
    country_code = params[:country_code].to_s.upcase
    nager_base   = Setting.plugin_redmine_non_working_days['nager_api_base'] ||
                   'https://date.nager.at'

    holidays = fetch_holidays_from_api(nager_base, year, country_code)

    if holidays.nil?
      flash[:error] = l(:error_non_working_day_holidays_fetch_failed)
      return redirect_to fetch_non_working_day_holidays_path(year: year)
    end

    NonWorkingDayEntry.transaction do
      # 指定年の holiday を国コードに関わらず全削除して置き換え
      NonWorkingDayEntry.holidays
        .where('EXTRACT(YEAR FROM date) = ?', year)
        .delete_all

      # Nager.Date API は州・地域ごとの祝日を別レコードとして返すため、
      # 同一日付・同一名称のものが重複して含まれる（例: 米国の Good Friday）。
      # 非稼働日カレンダーとしては日付＋名称が同じなら1件で十分なため重複排除する。
      holidays
        .map { |h| { date: Date.parse(h['date']), title: h['localName'].presence || h['name'] } }
        .uniq { |h| [h[:date], h[:title]] }
        .each do |h|
          NonWorkingDayEntry.create!(
            date:         h[:date],
            title:        h[:title],
            kind:         'holiday',
            country_code: country_code
          )
        end
    end

    RedmineNonWorkingDays::Cache.invalidate!
    flash[:notice] = l(:notice_non_working_day_holidays_imported, count: holidays.size, year: year, country: country_code)
    redirect_to non_working_days_path(year: year)
  end

  # GET /non_working_days/api/days.json
  def api_days
    from, to = resolve_date_range
    return render_api_error(422, l(:error_non_working_day_invalid_params)) if from.nil? || to.nil?
    return render_api_error(422, l(:error_non_working_day_range_too_large)) if (to - from) > 365 * 50

    kinds = params[:kind]&.split(',')&.map(&:strip)

    days = RedmineNonWorkingDays::Cache.expand_for_range(from, to, kinds: kinds)
    render json: {
      non_working_days: days.map do |d|
        { date: d[:date].to_s, title: d[:title], kind: d[:kind], country_code: d[:country_code] }
      end
    }
  end

  private

  def bulk_ids
    Array(params[:ids]).map(&:to_i).reject(&:zero?)
  end

  def carried_rule_type
    type = params[:rule_type]
    NonWorkingDayRule::RULE_TYPES.include?(type) ? type : NonWorkingDayRule::RULE_TYPES.first
  end

  def carried_date(key)
    Date.parse(params[key].to_s)
  rescue ArgumentError, TypeError
    Date.today
  end

  def entry_params
    params.require(:non_working_day_entry).permit(:date, :title, :kind, :country_code)
  end

  def rule_params_params
    p = params.require(:non_working_day_rule).permit(:title, :rule_type, :start_date, :end_date,
                                                      rule_params: {})
    # rule_params は JSON テキストで受け取る場合も考慮
    if p[:rule_params].is_a?(String)
      p[:rule_params] = JSON.parse(p[:rule_params]) rescue {}
    end
    p
  end

  def resolve_date_range
    if params[:from].present? && params[:to].present?
      from = Date.parse(params[:from])
      to   = Date.parse(params[:to])
      return [nil, nil] if to < from
      [from, to]
    elsif params[:from].present? || params[:to].present?
      [nil, nil]  # 片方のみは 422
    else
      year = (params[:year] || Date.today.year).to_i
      [Date.new(year, 1, 1), Date.new(year, 12, 31)]
    end
  rescue ArgumentError
    [nil, nil]
  end

  def require_api_access
    unless Setting.rest_api_enabled?
      render json: { error: 'REST API disabled' }, status: :forbidden
      return false
    end
    find_current_user
    unless User.current.logged?
      render json: { error: 'Unauthorized' }, status: :unauthorized
      return false
    end
  end

  def render_api_error(status, message)
    render json: { error: message }, status: status
  end

  def fetch_available_countries(base_url)
    cache_key = 'non_working_days/available_countries'
    Rails.cache.fetch(cache_key, expires_in: 24.hours) do
      uri      = URI("#{base_url}/api/v3/AvailableCountries")
      response = Net::HTTP.get_response(uri)
      JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
    end
  rescue StandardError
    []
  end

  def fetch_holidays_from_api(base_url, year, country_code)
    uri      = URI("#{base_url}/api/v3/PublicHolidays/#{year}/#{country_code}")
    response = Net::HTTP.get_response(uri)
    return nil unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    data.is_a?(Array) && data.any? ? data : nil
  rescue StandardError
    nil
  end
end
