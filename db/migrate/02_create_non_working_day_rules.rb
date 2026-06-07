# frozen_string_literal: true

class CreateNonWorkingDayRules < ActiveRecord::Migration[7.2]
  def change
    create_table :non_working_day_rules do |t|
      t.string :title,     null: false
      t.string :rule_type, null: false
      t.text   :rule_params
      t.date   :start_date
      t.date   :end_date
      t.timestamps
    end
    add_index :non_working_day_rules, :rule_type
  end
end
