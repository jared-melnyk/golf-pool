class AddRememberTokenDigestToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :remember_token_digest, :string
  end
end
