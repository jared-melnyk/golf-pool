class AddPositionDisplayToTournamentResults < ActiveRecord::Migration[8.1]
  def change
    add_column :tournament_results, :position_display, :string
    add_index :tournament_results, :position_display
  end
end
