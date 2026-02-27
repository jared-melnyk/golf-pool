class CreatePoolTournamentOdds < ActiveRecord::Migration[8.1]
  def change
    create_table :pool_tournament_odds do |t|
      t.references :pool_tournament, null: false, foreign_key: true
      t.references :golfer, null: false, foreign_key: true
      t.integer :american_odds, null: false
      t.string :vendor
      t.datetime :locked_at, null: false

      t.timestamps
    end

    add_index :pool_tournament_odds, [ :pool_tournament_id, :golfer_id ], unique: true, name: "index_pool_tournament_odds_on_pt_and_golfer"
  end
end

