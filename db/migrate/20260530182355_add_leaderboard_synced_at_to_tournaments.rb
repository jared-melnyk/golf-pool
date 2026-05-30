class AddLeaderboardSyncedAtToTournaments < ActiveRecord::Migration[8.1]
  def change
    add_column :tournaments, :leaderboard_synced_at, :datetime
  end
end
