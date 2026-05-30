# frozen_string_literal: true

class AddOddsLockedAtToPoolTournaments < ActiveRecord::Migration[8.1]
  def change
    add_column :pool_tournaments, :odds_locked_at, :datetime
  end
end
