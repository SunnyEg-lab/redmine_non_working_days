# frozen_string_literal: true

RedmineApp::Application.routes.draw do
  scope '/non_working_days' do
    # Admin UI
    get    '/',               to: 'non_working_days#index',          as: 'non_working_days'
    get    '/entries/new',    to: 'non_working_days#new_entry',      as: 'new_non_working_day_entry'
    post   '/entries',        to: 'non_working_days#create_entry',   as: 'non_working_day_entries'
    delete '/entries/:id',    to: 'non_working_days#destroy_entry',  as: 'non_working_day_entry'
    delete '/entries',        to: 'non_working_days#destroy_entries',as: 'bulk_destroy_non_working_day_entries'
    get    '/rules/new',      to: 'non_working_days#new_rule',       as: 'new_non_working_day_rule'
    post   '/rules',          to: 'non_working_days#create_rule',    as: 'non_working_day_rules'
    delete '/rules/:id',      to: 'non_working_days#destroy_rule',   as: 'non_working_day_rule'
    delete '/rules',          to: 'non_working_days#destroy_rules',  as: 'bulk_destroy_non_working_day_rules'
    delete '/destroy_all',    to: 'non_working_days#destroy_all',    as: 'destroy_all_non_working_days'
    get    '/holidays/fetch', to: 'non_working_days#fetch_holidays', as: 'fetch_non_working_day_holidays'
    post   '/holidays/import',to: 'non_working_days#import_holidays',as: 'import_non_working_day_holidays'

    # External API
    get '/api/days.json', to: 'non_working_days#api_days'
  end
end
