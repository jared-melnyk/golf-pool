class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.references :event, null: false, foreign_key: true
      t.references :round, null: false, foreign_key: true
      t.string :game_type, null: false, default: "best_ball"
      t.boolean :submitted, null: false, default: false
      t.timestamps
    end
  end
end
