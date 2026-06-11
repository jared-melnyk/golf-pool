# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Game setups", type: :request do
  let(:user) { User.create!(name: "Host", email: "host@test.com", password: "pw") }
  let(:game) { Game.create!(name: "Saturday", creator: user, status: "draft") }

  before do
    GameMembership.create!(game: game, user: user, role: "host")
    post login_path, params: { email: user.email, password: "pw" }
  end

  it "saves course and advances to format step" do
    snapshot = {
    golf_course_api_course_id: 1,
    course_name: "Test Course",
    club_name: "Test Club",
    tee_name: "Blue",
    tee_gender: "male",
    course_rating: 72.0,
    slope_rating: 128,
    par_total: 72,
    hole_pars: Array.new(18, 4),
    hole_handicaps: (1..18).to_a,
    course_snapshot: { "id" => 1 }
  }

    allow_any_instance_of(GameSetupsController).to receive(:build_snapshot).and_return(snapshot)

    patch game_setup_path(game), params: {
      step: "course",
      round: { played_on: Date.today, golf_course_api_course_id: 1, tee_selector: "male:0" }
    }

    expect(response).to redirect_to(game_setup_path(game, step: "format"))
    expect(game.reload.round).to be_present
    expect(game.round.course_name).to eq("Test Course")
  end

  it "renders invite step with clipboard invite button" do
    round = Round.create!(
      name: "Round",
      played_on: Date.current,
      golf_course_api_course_id: 1,
      course_name: "Test",
      club_name: "Club",
      tee_name: "Blue",
      tee_gender: "male",
      course_rating: 72.0,
      slope_rating: 128,
      par_total: 72,
      hole_pars: Array.new(18, 4),
      hole_handicaps: (1..18).to_a,
      course_snapshot: { "id" => 1 }
    )
    game.update!(status: "active", game_type: "best_ball", round: round)

    get game_setup_path(game, step: "invite")
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Invite players")
    expect(response.body).to include('data-controller="clipboard"')
    expect(response.body).not_to include('readonly value="')
  end

  it "shows back link to format step from invite" do
    get game_setup_path(game, step: "invite")
    expect(response.body).to include("Game format")
    expect(response.body).to include(game_setup_path(game, step: "format"))
  end

  describe "event games with existing rounds" do
    let(:event) { Event.create!(name: "Bandon 2026") }
    let(:event_round) do
      Round.create!(
        event: event,
        name: "Saturday morning",
        played_on: Date.new(2026, 6, 14),
        golf_course_api_course_id: 1,
        course_name: "Wolf River Golf Park",
        club_name: "Wolf River Golf Park",
        tee_name: "Blue",
        tee_gender: "male",
        course_rating: 71.1,
        slope_rating: 124,
        par_total: 72,
        hole_pars: Array.new(18, 4),
        hole_handicaps: (1..18).to_a,
        course_snapshot: { "id" => 1 }
      )
    end
    let(:event_game) { Game.create!(name: "Saturday game", creator: user, status: "draft", event: event) }

    before do
      EventMembership.create!(event: event, user: user, role: "commissioner")
      GameMembership.create!(game: event_game, user: user, role: "host")
      event_round
    end

    it "shows existing round choices on the course step" do
      get game_setup_path(event_game, step: "course")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Use an existing event round")
      expect(response.body).to include("Saturday morning")
      expect(response.body).to include("Wolf River Golf Park")
    end

    it "links an existing event round without creating a new round" do
      expect do
        patch game_setup_path(event_game), params: {
          step: "course",
          round_source: "existing",
          existing_round_id: event_round.id
        }
      end.not_to change(Round, :count)

      expect(response).to redirect_to(game_setup_path(event_game, step: "format"))
      expect(event_game.reload.round).to eq(event_round)
    end

    it "rejects an existing round id from another event" do
      other_event = Event.create!(name: "Other trip")
      other_round = Round.create!(
        event: other_event,
        name: "Other round",
        played_on: Date.current,
        golf_course_api_course_id: 2,
        course_name: "Other Course",
        club_name: "Other Club",
        tee_name: "Blue",
        tee_gender: "male",
        course_rating: 72.0,
        slope_rating: 128,
        par_total: 72,
        hole_pars: Array.new(18, 4),
        hole_handicaps: (1..18).to_a,
        course_snapshot: { "id" => 2 }
      )

      patch game_setup_path(event_game), params: {
        step: "course",
        round_source: "existing",
        existing_round_id: other_round.id
      }

      expect(response).to redirect_to(game_setup_path(event_game, step: "course"))
      expect(flash[:alert]).to eq("Select a round from this event.")
      expect(event_game.reload.round).to be_nil
    end
  end

  it "returns course search results as a dropdown partial without a full page reload" do
    allow_any_instance_of(GameSetupsController).to receive(:golf_course_api_key_configured?).and_return(true)
    allow_any_instance_of(GameSetupsController).to receive(:golf_course_client).and_return(
      instance_double(
        GolfCourseApi::Client,
        search_courses: {
          "courses" => [
            {
              "id" => 12,
              "club_name" => "Pinehurst Resort",
              "course_name" => "No. 2",
              "location" => { "city" => "Pinehurst", "state" => "NC" }
            }
          ]
        }
      )
    )

    get search_courses_game_setup_path(game), params: { search_query: "pine" }, headers: { "X-Requested-With" => "XMLHttpRequest" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Pinehurst Resort")
    expect(response.body).to include('data-action="course-search#pick"')
    expect(response.body).not_to include("<!DOCTYPE html>")
  end

  it "returns course selection partial when a course is chosen" do
    course_payload = {
      "id" => 12,
      "club_name" => "Pinehurst Resort",
      "course_name" => "No. 2",
      "tees" => { "male" => [
        { "tee_name" => "Blue", "course_rating" => 72.0, "slope_rating" => 128, "par_total" => 72,
          "number_of_holes" => 18, "holes" => Array.new(18) { { "par" => 4, "handicap" => 1 } } }
      ] }
    }

    allow_any_instance_of(GameSetupsController).to receive(:golf_course_api_key_configured?).and_return(true)
    allow_any_instance_of(GameSetupsController).to receive(:golf_course_client).and_return(
      instance_double(GolfCourseApi::Client, course: course_payload)
    )

    get select_course_game_setup_path(game), params: { course_id: 12 }, headers: { "X-Requested-With" => "XMLHttpRequest" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('name="round[golf_course_api_course_id]"')
    expect(response.body).to include('value="12"')
    expect(response.body).to include('name="round[tee_selector]"')
  end
end
