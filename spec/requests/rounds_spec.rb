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
    it "shows the typeahead course search UI" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(commissioner)

      get new_event_round_path(event)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-controller="course-search"')
      expect(response.body).to include("Type at least 2 characters to search.")
      expect(response.body).to include('name="round[name]"')
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

      it "returns course search results as a dropdown partial" do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(commissioner)

        get search_courses_event_rounds_path(event), params: { search_query: "murray" }, headers: { "X-Requested-With" => "XMLHttpRequest" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Murray Golf Club")
        expect(response.body).to include('data-action="course-search#pick"')
        expect(response.body).not_to include("<!DOCTYPE html>")
      end

      it "returns course selection with tee options and default round name" do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(commissioner)

        get select_course_event_rounds_path(event), params: { course_id: 99 }, headers: { "X-Requested-With" => "XMLHttpRequest" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('name="round[golf_course_api_course_id]"')
        expect(response.body).to include('value="99"')
        expect(response.body).to include('name="round[tee_selector]"')
        expect(response.body).to include("Male")
        expect(response.body).not_to include("Female")
        expect(response.body).to include("6,348 yds")
        expect(response.body).to include('value="Round at Course No. 1"')
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

        get select_course_event_rounds_path(event), params: { course_id: 99 }, headers: { "X-Requested-With" => "XMLHttpRequest" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Blue")
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
      expect(response.body).to include("Cannot manage rounds when an event is completed.")
    end
  end

  describe "GET /events/:event_token/rounds/:id/edit" do
    let(:round) do
      Round.create!(
        event: event,
        name: "Saturday",
        played_on: Date.new(2026, 6, 14),
        golf_course_api_course_id: 99,
        course_name: "Course No. 1",
        club_name: "Murray Golf Club",
        tee_name: "Blue",
        tee_gender: "male",
        course_rating: 72.1,
        slope_rating: 131,
        par_total: 72,
        hole_pars: Array.new(18, 4),
        hole_handicaps: (1..18).to_a,
        course_snapshot: {
          "id" => 99,
          "club_name" => "Murray Golf Club",
          "course_name" => "Course No. 1",
          "tees" => { "male" => [ { "tee_name" => "Blue", "number_of_holes" => 18, "course_rating" => 72.1, "slope_rating" => 131, "par_total" => 72, "holes" => (1..18).map { |n| { "par" => 4, "handicap" => n } } } ] }
        }
      )
    end

    it "shows the edit form with existing round data" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(commissioner)

      get edit_event_round_path(event, round)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Edit round")
      expect(response.body).to include('value="Saturday"')
      expect(response.body).to include('value="99"')
    end
  end

  describe "PATCH /events/:event_token/rounds/:id" do
    let(:client) { instance_double(GolfCourseApi::Client) }
    let(:round) do
      Round.create!(
        event: event,
        name: "Old name",
        played_on: Date.new(2026, 6, 14),
        golf_course_api_course_id: 99,
        course_name: "Course No. 1",
        club_name: "Murray Golf Club",
        tee_name: "Blue",
        tee_gender: "male",
        course_rating: 72.1,
        slope_rating: 131,
        par_total: 72,
        hole_pars: Array.new(18, 4),
        hole_handicaps: (1..18).to_a,
        course_snapshot: { "id" => 99 }
      )
    end

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

    it "allows a commissioner to update a round" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(commissioner)

      patch event_round_path(event, round), params: {
        round: {
          name: "Updated round",
          played_on: "2026-06-15",
          golf_course_api_course_id: "99",
          tee_selector: "male:0"
        }
      }

      expect(response).to redirect_to(event_path(event))
      expect(round.reload.name).to eq("Updated round")
      expect(round.played_on).to eq(Date.new(2026, 6, 15))
    end
  end

  describe "DELETE /events/:event_token/rounds/:id" do
    let!(:round) do
      Round.create!(
        event: event,
        name: "Saturday",
        played_on: Date.new(2026, 6, 14),
        golf_course_api_course_id: 99,
        course_name: "Course No. 1",
        club_name: "Murray Golf Club",
        tee_name: "Blue",
        tee_gender: "male",
        course_rating: 72.1,
        slope_rating: 131,
        par_total: 72,
        hole_pars: Array.new(18, 4),
        hole_handicaps: (1..18).to_a,
        course_snapshot: { "id" => 99 }
      )
    end

    it "allows a commissioner to delete an unused round" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(commissioner)

      expect do
        delete event_round_path(event, round)
      end.to change(Round, :count).by(-1)

      expect(response).to redirect_to(event_path(event))
    end

    it "blocks deletion when games use the round" do
      user = commissioner
      game = Game.create!(name: "Best Ball", creator: user, status: "draft", event: event, round: round)
      GameMembership.create!(game: game, user: user, role: "host")
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(commissioner)

      expect do
        delete event_round_path(event, round)
      end.not_to change(Round, :count)

      expect(response).to redirect_to(event_path(event))
      follow_redirect!
      expect(response.body).to include("Cannot delete this round")
    end
  end
end
