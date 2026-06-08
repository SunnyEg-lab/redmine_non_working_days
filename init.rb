# frozen_string_literal: true

require 'net/http'
require 'json'
require 'set'

require_relative 'lib/redmine_non_working_days/cache'
require_relative 'lib/redmine_non_working_days/date_calculation_patch'
require_relative 'lib/redmine_non_working_days/gantt_helper'
require_relative 'lib/redmine_non_working_days/gantt_patch'
require_relative 'lib/redmine_non_working_days/hooks'

Redmine::Plugin.register :redmine_non_working_days do
  name        'Redmine Non Working Days'
  author      'SunnyEG'
  author_url  'https://github.com/SunnyEg-lab'
  url         'https://github.com/SunnyEg-lab/redmine_non_working_days'
  description 'Manage non-working days by public holidays, custom dates, and recurring rules'
  version     '1.0.0'

  settings default: { 'nager_api_base' => 'https://date.nager.at' },
           partial: 'settings/non_working_days_settings'

  menu :admin_menu,
       :non_working_days,
       { controller: 'non_working_days', action: 'index' },
       caption: :label_non_working_days,
       icon:    'time',
       last:    false
end

Rails.application.config.assets.precompile += %w[non_working_days.js non_working_days.css]

# プラグインローダーが init.rb を Rails.application.config.to_prepare /
# ActiveSupport::Reloader.to_prepare のコールバックチェーン実行中に読み込むため、
# これらのコールバック内で prepend を行っても登録タイミングの都合で実行されない。
# よって init.rb 読み込み時点（コア定義済み）で直接 prepend する。
require 'redmine/utils/date_calculation'
require 'redmine/helpers/gantt'
Redmine::Utils::DateCalculation.prepend RedmineNonWorkingDays::DateCalculationPatch
Redmine::Helpers::Gantt.prepend RedmineNonWorkingDays::GanttPatch
# NOTE: cache_store は config/environments/production.rb で設定すること。
# config.cache_store = :file_store, Rails.root.join('tmp', 'cache')
