# frozen_string_literal: true

class AddPayoutCurveToTournaments < ActiveRecord::Migration[8.1]
  def change
    add_column :tournaments, :payout_curve_source, :string
    add_column :tournaments, :payout_curve, :jsonb
    add_column :tournaments, :payout_curve_built_at, :datetime
  end
end
