class ModerationActionsController < ApplicationController
  filter_access_to :all

  def index
    @moderation_actions = ModerationAction.order("created_at DESC").page(params[:page])
  end
end

