# frozen_string_literal: true

class ChangeGolfCourseApiCourseIdToString < ActiveRecord::Migration[8.1]
  def up
    change_column :rounds, :golf_course_api_course_id, :string, null: false
  end

  def down
    change_column :rounds, :golf_course_api_course_id, :integer, using: "golf_course_api_course_id::integer", null: false
  end
end
