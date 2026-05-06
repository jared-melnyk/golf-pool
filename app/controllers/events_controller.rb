class EventsController < ApplicationController
  def index
    @events = current_user.events.order(:name)
  end

  def new
    @event = Event.new
  end

  def create
    @event = Event.new(event_params)
    if @event.save
      @event.event_memberships.create!(user: current_user, role: "commissioner")
      redirect_to @event, notice: "Event created. Invite players with the link below."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @event = Event.find_by!(token: params[:token])
    if @event.member?(current_user)
      @membership = @event.event_memberships.find_by!(user: current_user)
      @memberships = @event.event_memberships.includes(:user).order("users.name")
    else
      render :show_join
    end
  end

  def update
    @event = Event.find_by!(token: params[:token])
    unless @event.member?(current_user)
      redirect_to @event, alert: "You must be a member of this event."
      return
    end
    unless @event.commissioner?(current_user)
      redirect_to @event, alert: "Only commissioners can update this event."
      return
    end
    if @event.update(event_update_params)
      redirect_to @event, notice: "Event updated."
    else
      @membership = @event.event_memberships.find_by!(user: current_user)
      @memberships = @event.event_memberships.includes(:user).order("users.name")
      render :show, status: :unprocessable_entity
    end
  end

  def join
    @event = Event.find_by!(token: params[:token])
    if @event.member?(current_user)
      redirect_to @event, notice: "You're already in this event."
    else
      @event.event_memberships.create!(user: current_user, role: "player")
      redirect_to @event, notice: "You joined the event."
    end
  end

  private

  def event_params
    params.require(:event).permit(:name)
  end

  def event_update_params
    params.require(:event).permit(:status)
  end
end
