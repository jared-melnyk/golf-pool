class AddTotalPrizePoolToTournaments < ActiveRecord::Migration[8.1]
  def change
    add_column :tournaments, :total_prize_pool, :decimal, precision: 12, scale: 2
  end
end
