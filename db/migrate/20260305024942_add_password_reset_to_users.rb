class AddPasswordResetToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :password_reset_token_digest, :string
    add_column :users, :password_reset_sent_at, :datetime
  end
end
