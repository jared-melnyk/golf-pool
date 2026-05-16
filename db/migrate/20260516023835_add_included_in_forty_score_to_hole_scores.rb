class AddIncludedInFortyScoreToHoleScores < ActiveRecord::Migration[8.1]
  def change
    add_column :hole_scores, :included_in_forty_score, :boolean, null: false, default: false
  end
end
