# frozen_string_literal: true

class AddResultsSyncedAtToTournaments < ActiveRecord::Migration[8.0]
  def change
    add_column :tournaments, :results_synced_at, :datetime
  end
end
