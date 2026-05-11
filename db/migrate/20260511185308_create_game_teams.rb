class CreateGameTeams < ActiveRecord::Migration[8.1]
  def change
    create_table :game_teams do |t|
      t.references :game, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
    end
  end
end
