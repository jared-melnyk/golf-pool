class RemoveSlotFivePickGolfers < ActiveRecord::Migration[8.1]
  def change
    PickGolfer.where(slot: 5).delete_all
  end
end
