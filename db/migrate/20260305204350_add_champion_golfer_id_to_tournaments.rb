class AddChampionGolferIdToTournaments < ActiveRecord::Migration[8.1]
  def change
    add_column :tournaments, :champion_golfer_id, :bigint
    add_index :tournaments, :champion_golfer_id
    add_foreign_key :tournaments, :golfers, column: :champion_golfer_id
  end
end
