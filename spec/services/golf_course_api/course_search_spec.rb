# frozen_string_literal: true

require "rails_helper"

RSpec.describe GolfCourseApi::CourseSearch do
  let(:client) { instance_double(GolfCourseApi::Client) }
  let(:billy_caldwell) do
    {
      "id" => 1,
      "club_name" => "Billy Caldwell Golf Club",
      "course_name" => "Billy Caldwell Golf Course",
      "location" => { "city" => "Chicago", "state" => "IL" }
    }
  end
  let(:bill_roberts) do
    {
      "id" => 2,
      "club_name" => "Bill Roberts Golf Course",
      "course_name" => "Main",
      "location" => { "city" => "Austin", "state" => "TX" }
    }
  end
  let(:pinehurst_no2) do
    {
      "id" => 3,
      "club_name" => "Pinehurst Resort",
      "course_name" => "No. 2",
      "location" => { "city" => "Pinehurst", "state" => "NC" }
    }
  end

  subject(:search) { described_class.new(client: client) }

  def stub_search(queries_to_courses)
    allow(client).to receive(:search_courses) do |search_query:|
      courses = queries_to_courses[search_query] || []
      { "courses" => courses }
    end
  end

  it "returns API results when the API already matches the query" do
    stub_search("pinehurst" => [ pinehurst_no2 ])

    expect(search.call("pinehurst")).to eq([ pinehurst_no2 ])
  end

  it "finds Billy Caldwell when typing a three-letter prefix via supplemental search" do
    stub_search(
      "bil" => [],
      "bill" => [ bill_roberts, billy_caldwell ],
      "billy" => [ billy_caldwell ]
    )

    results = search.call("bil")

    expect(results).to include(billy_caldwell)
    expect(results).to include(bill_roberts)
  end

  it "finds courses when typing two letters" do
    stub_search(
      "bi" => [],
      "bil" => [],
      "bill" => [ bill_roberts, billy_caldwell ],
      "billy" => [ billy_caldwell ]
    )

    expect(search.call("bi")).to include(billy_caldwell)
  end

  it "filters multi-word queries against a stem search" do
    stub_search(
      "billy cald" => [],
      "billy" => [ billy_caldwell, bill_roberts ]
    )

    results = search.call("billy cald")

    expect(results).to eq([ billy_caldwell ])
  end

  it "dedupes courses returned from multiple supplemental queries" do
    stub_search(
      "bil" => [],
      "bill" => [ billy_caldwell ],
      "billy" => [ billy_caldwell ]
    )

    expect(search.call("bil").size).to eq(1)
  end
end
