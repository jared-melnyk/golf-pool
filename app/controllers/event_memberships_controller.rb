class EventMembershipsController < ApplicationController
  # Nested under `resources :events, param: :token` — Rails exposes parent segment as `event_token`.
  def update
    @event = Event.find_by!(token: params[:event_token])
    membership = @event.event_memberships.find(params[:id])
    unless @event.commissioner?(current_user)
      redirect_to @event, alert: "Only commissioners can promote members."
      return
    end
    unless membership.player?
      redirect_to @event, alert: "That member is already a commissioner."
      return
    end
    membership.update!(role: "commissioner")
    redirect_to @event, notice: "#{membership.user.name} is now a commissioner."
  end

  def destroy
    @event = Event.find_by!(token: params[:event_token])
    membership = @event.event_memberships.find(params[:id])

    if membership.user_id == current_user.id
      if membership.commissioner? && @event.event_memberships.where(role: "commissioner").count <= 1
        redirect_to @event, alert: "You are the only commissioner. Add another commissioner before leaving."
        return
      end
      membership.destroy!
      redirect_to events_path, notice: "You left the event."
      return
    end

    unless @event.commissioner?(current_user)
      redirect_to @event, alert: "Only commissioners can remove other members."
      return
    end

    if membership.commissioner?
      redirect_to @event, alert: "Commissioners cannot remove other commissioners."
      return
    end

    membership.destroy!
    redirect_to @event, notice: "Member removed."
  end
end
