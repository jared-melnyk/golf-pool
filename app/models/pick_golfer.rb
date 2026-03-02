class PickGolfer < ApplicationRecord
  belongs_to :pick
  belongs_to :golfer

  validates :slot, presence: true, inclusion: { in: 1..4 }
  validates :pick_id, uniqueness: { scope: :slot }
  validates :pick_id, uniqueness: { scope: :golfer_id }
end
