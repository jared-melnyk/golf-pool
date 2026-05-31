# frozen_string_literal: true

class AddLiveRoundNumberToTournaments < ActiveRecord::Migration[8.1]
  def change
    add_column :tournaments, :live_round_number, :integer
  end
end
