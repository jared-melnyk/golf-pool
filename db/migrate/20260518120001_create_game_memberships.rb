class CreateGameMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :game_memberships do |t|
      t.references :game, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false
      t.timestamps
    end
    add_index :game_memberships, [ :game_id, :user_id ], unique: true
  end
end
