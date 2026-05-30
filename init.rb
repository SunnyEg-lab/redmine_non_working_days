require_relative 'lib/redmine_non_working_days/date_calculation_patch'
require_relative 'lib/redmine_non_working_days/non_working_day_helper'
require_relative 'lib/redmine_non_working_days/gantt_patch'

Redmine::Plugin.register :redmine_non_working_days do
  name 'Redmine Non Working Days'
  author 'Nakazato'
  description 'Add company holidays and public holidays as non-working days'
  version '0.0.1'
end

ActionView::Base.send :include, RedmineNonWorkingDays::NonWorkingDayHelper

# 期日計算ロジックの上書き
require 'redmine/utils/date_calculation'
Redmine::Utils::DateCalculation.prepend RedmineNonWorkingDays::DateCalculationPatch

# ガントチャート表示ロジックの上書き
require 'redmine/helpers/gantt'
Redmine::Helpers::Gantt.prepend RedmineNonWorkingDays::GanttPatch

Rails.application.config.assets.precompile += %w[
  non_working_days.js
]

Rails.application.config.to_prepare do
  require_dependency 'redmine_non_working_days/hooks/easy_gantt_hook'
end

