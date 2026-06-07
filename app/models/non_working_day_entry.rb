# frozen_string_literal: true

class NonWorkingDayEntry < ActiveRecord::Base
  KINDS = %w[holiday custom_fixed].freeze

  validates :date,  presence: true
  validates :title, presence: true
  validates :kind,  presence: true, inclusion: { in: KINDS }
  # country_code は Nager.Date API 取得時のみ設定。手動登録時は NULL。

  scope :holidays,     -> { where(kind: 'holiday') }
  scope :custom_fixed, -> { where(kind: 'custom_fixed') }
  scope :for_year,     ->(year) { where(date: Date.new(year, 1, 1)..Date.new(year, 12, 31)) }
  scope :for_range,    ->(from, to) { where(date: from..to) }

  after_save    { RedmineNonWorkingDays::Cache.invalidate! }
  after_destroy { RedmineNonWorkingDays::Cache.invalidate! }
end
