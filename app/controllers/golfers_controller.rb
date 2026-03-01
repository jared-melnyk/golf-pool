class GolfersController < ApplicationController
  def index
    @golfers = Golfer.order(:name)
  end
end
