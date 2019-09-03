class AddCriteriaRulesToMessages < ActiveRecord::Migration[5.2]
  def change
    add_column :messages, :criteria_rules, :json, null: false, default: {}
  end
end
