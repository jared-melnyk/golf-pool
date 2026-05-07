# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Rounds", type: :request do
  let(:commissioner) { User.create!(email: "commish@example.com", name: "Commish", password: "password") }
  let(:player) { User.create!(email: "player@example.com", name: "Player", password: "password") }
  let(:event) { Event.create!(name: "Bandon 2026") }

  before do
    event.event_memberships.create!(user: commissioner, role: "commissioner")
  end

  describe "GET /events/:event_token/rounds/new" do
    it "shows setup instructions when GOLF_COURSE_API_KEY is not set" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("GOLF_COURSE_API_KEY").and_return(nil)

      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(commissioner)

      get new_event_round_path(event), params: { search_query: "pinehurst" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("GOLF_COURSE_API_KEY")
      expect(response.body).to include(".env.example")
    end

    context "when GOLF_COURSE_API_KEY is configured" do
      let(:client) { instance_double(GolfCourseApi::Client) }

      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("GOLF_COURSE_API_KEY").and_return("test-key")
        allow(GolfCourseApi::Client).to receive(:new).and_return(client)
        allow(client).to receive(:search_courses).and_return(
          { "courses" => [ { "id" => 99, "club_name" => "Murray Golf Club", "course_name" => "Course No. 1", "location" => { "city" => "Murray", "state" => "KY" } } ] }
        )
        allow(client).to receive(:course).with(id: 99).and_return(
          {
            "id" => 99,
            "club_name" => "Murray Golf Club",
            "course_name" => "Course No. 1",
            "tees" => {
              "male" => [ { "tee_name" => "Blue", "total_yards" => 6348, "number_of_holes" => 18, "course_rating" => 72.1, "slope_rating" => 131, "par_total" => 72, "holes" => (1..18).map { |n| { "par" => 4, "handicap" => n } } } ],
              "female" => [ { "tee_name" => "Gold", "total_yards" => 6012, "number_of_holes" => 18, "course_rating" => 74.2, "slope_rating" => 136, "par_total" => 72, "holes" => (1..18).map { |n| { "par" => 4, "handicap" => n } } } ]
            }
          }
        )
      end

      it "shows only male tee options in v1" do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(commissioner)

        get new_event_round_path(event), params: { search_query: "murray", course_id: 99 }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Male")
        expect(response.body).not_to include("Female")
        expect(response.body).to include("6,348 yds")
      end

      it "shows tee options when course payload is wrapped under course key" do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(commissioner)
        allow(client).to receive(:course).with(id: 99).and_return(
          {
            "course" => {
              "id" => 99,
              "club_name" => "Murray Golf Club",
              "course_name" => "Course No. 1",
              "tees" => {
                "Men" => [ { "tee_name" => "Blue", "total_yards" => 6348, "number_of_holes" => 18, "course_rating" => 72.1, "slope_rating" => 131, "par_total" => 72, "holes" => (1..18).map { |n| { "par" => 4, "handicap" => n } } } ]
              }
            }
          }
        )

        get new_event_round_path(event), params: { search_query: "murray", course_id: 99 }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Blue")
      end

      it "prefills a default round name after selecting a course" do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(commissioner)
        allow(Date).to receive(:current).and_return(Date.new(2026, 6, 10))

        get new_event_round_path(event), params: { search_query: "murray", course_id: 99 }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('value="Round at Course No. 1"')
      end

      it "hides search result links after a course is selected" do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(commissioner)

        get new_event_round_path(event), params: { search_query: "murray", course_id: 99 }

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("course_id=99&amp;search_query=murray")
      end
    end
  end

  describe "POST /events/:event_token/rounds" do
    let(:client) { instance_double(GolfCourseApi::Client) }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("GOLF_COURSE_API_KEY").and_return("test-key")
      allow(GolfCourseApi::Client).to receive(:new).and_return(client)
      allow(client).to receive(:course).with(id: 99).and_return(
        {
          "id" => 99,
          "club_name" => "Murray Golf Club",
          "course_name" => "Course No. 1",
          "tees" => {
            "male" => [
              {
                "tee_name" => "Blue",
                "number_of_holes" => 18,
                "course_rating" => 72.1,
                "slope_rating" => 131,
                "par_total" => 72,
                "holes" => (1..18).map { |n| { "par" => 4, "handicap" => n } }
              }
            ]
          }
        }
      )
    end

    it "allows a commissioner to create a round from GolfCourseAPI snapshot" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(commissioner)

      expect do
        post event_rounds_path(event), params: {
          round: {
            name: "Round 1",
            played_on: "2026-06-10",
            golf_course_api_course_id: "99",
            tee_selector: "male:0"
          }
        }
      end.to change(Round, :count).by(1)

      round = Round.last
      expect(round.course_name).to eq("Course No. 1")
      expect(round.tee_name).to eq("Blue")
      expect(round.hole_pars).to eq(Array.new(18, 4))
      expect(round.hole_handicaps).to eq((1..18).to_a)
      expect(response).to redirect_to(event_path(event))
    end

    it "rejects non-commissioner round creation" do
      event.event_memberships.create!(user: player, role: "player")
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(player)

      expect do
        post event_rounds_path(event), params: {
          round: {
            name: "Round 1",
            played_on: "2026-06-10",
            golf_course_api_course_id: "99",
            tee_selector: "male:0"
          }
        }
      end.not_to change(Round, :count)

      expect(response).to redirect_to(event_path(event))
    end

    it "blocks round creation when event is completed" do
      event.update!(status: "completed")
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(commissioner)

      expect do
        post event_rounds_path(event), params: {
          round: {
            name: "Round 1",
            played_on: "2026-06-10",
            golf_course_api_course_id: "99",
            tee_selector: "male:0"
          }
        }
      end.not_to change(Round, :count)

      expect(response).to redirect_to(event_path(event))
      follow_redirect!
      expect(response.body).to include("Cannot create rounds when an event is completed.")
    end
  end
end
