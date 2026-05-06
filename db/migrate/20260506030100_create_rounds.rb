class CreateRounds < ActiveRecord::Migration[8.1]
  def change
    create_table :rounds do |t|
      t.references :event, null: false, foreign_key: true
      t.string :name, null: false
      t.date :played_on, null: false

      t.integer :golf_course_api_course_id, null: false
      t.string :course_name, null: false
      t.string :club_name
      t.string :tee_name, null: false
      t.string :tee_gender, null: false

      t.decimal :course_rating, precision: 5, scale: 2, null: false
      t.integer :slope_rating, null: false
      t.integer :par_total, null: false
      t.integer :hole_pars, array: true, default: [], null: false
      t.integer :hole_handicaps, array: true, default: [], null: false

      t.jsonb :course_snapshot, default: {}, null: false

      t.timestamps
    end
  end
end
