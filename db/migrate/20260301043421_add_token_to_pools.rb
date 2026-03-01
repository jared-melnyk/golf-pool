class AddTokenToPools < ActiveRecord::Migration[8.1]
  def change
    add_column :pools, :token, :string
    add_index :pools, :token, unique: true

    reversible do |dir|
      dir.up do
        Pool.reset_column_information
        Pool.find_each do |pool|
          pool.update_column(:token, SecureRandom.urlsafe_base64(16))
        end
        change_column_null :pools, :token, false
      end
    end
  end
end
