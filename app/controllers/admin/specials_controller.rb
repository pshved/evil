class Admin::SpecialsController < ApplicationController
  # Since all actions are only visible to admins, do not distinguish permissions
  filter_access_to :all, :require => :manage

  # A page that comprises links to other settings
  def index
  end
end

