# frozen_string_literal: true

class CreateNonWorkingDayEntries < ActiveRecord::Migration[7.2]
  def change
    create_table :non_working_day_entries do |t|
      t.date    :date,         null: false
      t.string  :title,        null: false
      t.string  :kind,         null: false
      t.string  :country_code
      t.timestamps
    end
    add_index :non_working_day_entries, [:kind, :date]
    add_index :non_working_day_entries, [:kind, :date, :country_code], name: 'idx_nwde_kind_date_country'
  end
end
