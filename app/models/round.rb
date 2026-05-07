class Round < ApplicationRecord
  belongs_to :event

  validates :name, :played_on, :course_name, :tee_name, :tee_gender, presence: true
  validates :golf_course_api_course_id, :slope_rating, :par_total, presence: true
  validates :course_rating, numericality: true
  validates :tee_gender, inclusion: { in: %w[male female] }
  validate :validate_hole_arrays

  def tee_total_yards
    tees = course_snapshot.is_a?(Hash) ? course_snapshot["tees"] : nil
    tee_list = tees.is_a?(Hash) ? tees[tee_gender] : nil
    tee = Array(tee_list).find { |candidate| candidate["tee_name"] == tee_name }
    tee && tee["total_yards"]
  end

  private

  def validate_hole_arrays
    errors.add(:hole_pars, "must have 18 values") unless hole_pars.is_a?(Array) && hole_pars.size == 18
    errors.add(:hole_handicaps, "must have 18 values") unless hole_handicaps.is_a?(Array) && hole_handicaps.size == 18
  end
end
