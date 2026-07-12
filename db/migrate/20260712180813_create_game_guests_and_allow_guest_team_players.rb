class CreateGameGuestsAndAllowGuestTeamPlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :game_guests do |t|
      t.references :game, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :handicap_index, precision: 5, scale: 1, null: false

      t.timestamps
    end

    change_column_null :game_team_players, :user_id, true
    add_reference :game_team_players, :game_guest, foreign_key: true, index: false
    add_index :game_team_players, :game_guest_id,
              unique: true,
              where: "game_guest_id IS NOT NULL",
              name: "index_game_team_players_on_game_guest_id_unique"
  end
end
