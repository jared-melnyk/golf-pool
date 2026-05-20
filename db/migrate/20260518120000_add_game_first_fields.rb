class AddGameFirstFields < ActiveRecord::Migration[8.1]
  class Game < ApplicationRecord
    self.table_name = "games"
  end

  def up
    add_column :games, :token, :string
    add_column :games, :creator_id, :bigint
    add_column :games, :name, :string
    add_column :games, :status, :string, null: false, default: "draft"

    add_index :games, :token, unique: true
    add_index :games, :creator_id
    add_foreign_key :games, :users, column: :creator_id

    say_with_time "Backfilling game tokens" do
      Game.reset_column_information
      Game.where(token: nil).find_each do |game|
        game.update_columns(token: SecureRandom.urlsafe_base64(16))
      end
    end
    change_column_null :games, :token, false

    execute <<~SQL.squish
      UPDATE games g
      SET name = CONCAT(
        INITCAP(REPLACE(g.game_type, '_', ' ')), ' · ',
        r.course_name, ' · ',
        TO_CHAR(r.played_on, 'Mon DD')
      )
      FROM rounds r
      WHERE g.round_id = r.id AND g.name IS NULL
    SQL
    execute "UPDATE games SET name = 'Untitled game' WHERE name IS NULL"
    change_column_null :games, :name, false

    execute <<~SQL.squish
      UPDATE games SET status = CASE WHEN submitted = TRUE THEN 'completed' ELSE 'active' END
    SQL

    execute <<~SQL.squish
      UPDATE games g
      SET creator_id = (
        SELECT em.user_id FROM event_memberships em
        WHERE em.event_id = g.event_id AND em.role = 'commissioner'
        ORDER BY em.created_at ASC LIMIT 1
      )
    SQL
    execute <<~SQL.squish
      UPDATE games g
      SET creator_id = (
        SELECT em.user_id FROM event_memberships em
        WHERE em.event_id = g.event_id
        ORDER BY em.created_at ASC LIMIT 1
      )
      WHERE creator_id IS NULL
    SQL
    change_column_null :games, :creator_id, false

    change_column_null :games, :event_id, true
    change_column_null :games, :round_id, true
    change_column_null :rounds, :event_id, true

    change_column_default :games, :game_type, from: "best_ball", to: nil
    change_column_null :games, :game_type, true

    remove_column :games, :submitted
  end

  def down
    add_column :games, :submitted, :boolean, null: false, default: false
    execute "UPDATE games SET submitted = TRUE WHERE status = 'completed'"
    execute "UPDATE games SET game_type = 'best_ball' WHERE game_type IS NULL"

    change_column_null :games, :game_type, false
    change_column_default :games, :game_type, from: nil, to: "best_ball"

    change_column_null :games, :event_id, false
    change_column_null :games, :round_id, false
    change_column_null :rounds, :event_id, false

    remove_foreign_key :games, column: :creator_id
    remove_index :games, :token
    remove_column :games, :token
    remove_column :games, :creator_id
    remove_column :games, :name
    remove_column :games, :status
  end
end
