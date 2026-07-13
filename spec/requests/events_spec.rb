# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Events", type: :request do
  let(:user) { User.create!(email: "u@example.com", name: "Owner", password: "password") }
  let(:player) { User.create!(email: "p@example.com", name: "Player", password: "password") }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  describe "POST /events" do
    it "creates an event and makes creator a commissioner" do
      expect do
        post events_path, params: { event: { name: "Spring scramble" } }
      end.to change(Event, :count).by(1)

      event = Event.last
      expect(response).to redirect_to(event_path(event))
      em = event.event_memberships.find_by!(user: user)
      expect(em.role).to eq("commissioner")
    end
  end

  describe "GET /events/:token" do
    let(:event) { Event.create!(name: "Open event") }

    before { event.event_memberships.create!(user: user, role: "commissioner") }

    it "shows join page for non-members" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(player)

      get event_path(event)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("You're not in this event yet.")
    end

    it "shows member page for members" do
      get event_path(event)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(event.name)
      expect(response.body).to include("Rounds")
    end

    it "shows overall low net and rounds before the members list" do
      get event_path(event)

      low_net_at = response.body.index("Overall low net")
      rounds_at = response.body.index(">Rounds<") || response.body.index("Rounds</h2>")
      members_at = response.body.index("Members</h2>")

      expect(low_net_at).to be_present
      expect(rounds_at).to be_present
      expect(members_at).to be_present
      expect(low_net_at).to be < rounds_at
      expect(rounds_at).to be < members_at
    end

    it "shows round details to any event member" do
      event.rounds.create!(
        name: "Round 1",
        played_on: Date.new(2026, 6, 10),
        golf_course_api_course_id: 99,
        course_name: "Course No. 1",
        club_name: "Murray Golf Club",
        tee_name: "Blue",
        tee_gender: "male",
        course_rating: BigDecimal("72.1"),
        slope_rating: 131,
        par_total: 72,
        hole_pars: Array.new(18, 4),
        hole_handicaps: (1..18).to_a,
        course_snapshot: {
          "tees" => {
            "male" => [
              { "tee_name" => "Blue", "total_yards" => 6348 }
            ]
          }
        }
      )
      event.event_memberships.create!(user: player, role: "player")
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(player)

      get event_path(event)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Round 1")
      expect(response.body).to include("Course No. 1")
      expect(response.body).to include("6,348 yds")
    end

    it "nests games under rounds with an Add game CTA" do
      round = event.rounds.create!(
        name: "Wolf River · Jul 16",
        played_on: Date.new(2026, 7, 16),
        golf_course_api_course_id: 1,
        course_name: "Wolf River Golf Park",
        club_name: "Wolf River Golf Park",
        tee_name: "Blue",
        tee_gender: "male",
        course_rating: BigDecimal("69.4"),
        slope_rating: 120,
        par_total: 72,
        hole_pars: Array.new(18, 4),
        hole_handicaps: (1..18).to_a,
        course_snapshot: { "id" => 1 }
      )
      Game.create!(
        name: "Best Ball · A",
        creator: user,
        status: "active",
        event: event,
        round: round,
        game_type: "best_ball"
      )

      get event_path(event)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Wolf River · Jul 16")
      expect(response.body).to include("Best Ball · A")
      expect(response.body).to include("Add game")
      expect(response.body).to include(new_event_round_game_path(event, round))
      expect(response.body).not_to include(">Create game<")
      expect(response.body).not_to match(/<h2[^>]*>Games<\/h2>/)
    end
  end

  describe "POST /events/:token/join" do
    let(:event) { Event.create!(name: "Joinable") }

    before do
      event.event_memberships.create!(user: user, role: "commissioner")
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(player)
    end

    it "adds player role membership" do
      expect do
        post join_event_path(event)
      end.to change { event.reload.users.include?(player) }.from(false).to(true)

      expect(EventMembership.find_by!(event: event, user: player).role).to eq("player")
    end
  end

  describe "PATCH /events/:token/event_memberships/:id" do
    let(:event) { Event.create!(name: "Promote test") }

    before do
      event.event_memberships.create!(user: user, role: "commissioner")
    end

    it "promotes a player to commissioner" do
      event.event_memberships.create!(user: player, role: "player")
      em = EventMembership.find_by!(event: event, user: player)

      patch event_event_membership_path(event, em)

      expect(response).to redirect_to(event_path(event))
      expect(em.reload.role).to eq("commissioner")
    end
  end
end
