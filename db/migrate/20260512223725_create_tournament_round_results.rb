class CreateTournamentRoundResults < ActiveRecord::Migration[8.1]
  def change
    create_table :tournament_round_results do |t|
      t.references :tournament, null: false, foreign_key: true
      t.references :golfer, null: false, foreign_key: true
      t.integer :round_number, null: false
      t.integer :score_to_par
      t.integer :last_hole_completed

      t.timestamps
    end
    add_index :tournament_round_results,
              [ :tournament_id, :golfer_id, :round_number ],
              unique: true,
              name: "idx_trr_tournament_golfer_round"

    add_column :tournaments, :live_results_synced_at, :datetime
  end
end
