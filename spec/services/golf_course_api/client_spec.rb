# frozen_string_literal: true

require "rails_helper"

RSpec.describe GolfCourseApi::Client do
  describe "#search_courses" do
    it "returns parsed courses payload" do
      response = instance_double(Net::HTTPOK, code: "200", body: {
        courses: [
          {
            id: 12,
            club_name: "Pinehurst Resort",
            course_name: "No. 2",
            location: { city: "Pinehurst", state: "NC" }
          }
        ]
      }.to_json)
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      allow(Net::HTTP).to receive(:start).and_return(response)

      client = described_class.new(api_key: "test-key")
      result = client.search_courses(search_query: "pinehurst")

      expect(result.fetch("courses").size).to eq(1)
      expect(result.fetch("courses").first.fetch("id")).to eq(12)
    end
  end

  describe "#course" do
    it "returns parsed course details payload" do
      response = instance_double(Net::HTTPOK, code: "200", body: {
        id: 99,
        course_name: "Murray Golf Club",
        tees: { male: [ { tee_name: "Blue", number_of_holes: 18, par_total: 72, course_rating: 72.1, slope_rating: 130, holes: [] } ] }
      }.to_json)
      allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      allow(Net::HTTP).to receive(:start).and_return(response)

      client = described_class.new(api_key: "test-key")
      result = client.course(id: 99)

      expect(result.fetch("id")).to eq(99)
      expect(result.fetch("course_name")).to eq("Murray Golf Club")
    end
  end
end
