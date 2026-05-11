class CreateHoleScores < ActiveRecord::Migration[8.1]
  def change
    create_table :hole_scores do |t|
      t.references :game_team_player, null: false, foreign_key: true
      t.integer :hole_number, null: false
      t.integer :gross_score
      t.timestamps
    end
    add_index :hole_scores, [ :game_team_player_id, :hole_number ], unique: true
  end
end
