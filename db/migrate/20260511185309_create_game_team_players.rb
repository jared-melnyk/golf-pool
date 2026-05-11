class CreateGameTeamPlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :game_team_players do |t|
      t.references :game_team, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.decimal :snapshot_handicap_index, precision: 5, scale: 1
      t.timestamps
    end
    add_index :game_team_players, [ :game_team_id, :user_id ], unique: true
  end
end
