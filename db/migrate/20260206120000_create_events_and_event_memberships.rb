# frozen_string_literal: true

class CreateEventsAndEventMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.string :name, null: false
      t.string :token, null: false
      t.string :status, null: false, default: "draft"

      t.timestamps
    end
    add_index :events, :token, unique: true

    create_table :event_memberships do |t|
      t.references :event, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false

      t.timestamps
    end
    add_index :event_memberships, [ :event_id, :user_id ], unique: true

    add_column :users, :ghin_handicap_index, :decimal, precision: 5, scale: 2
  end
end
