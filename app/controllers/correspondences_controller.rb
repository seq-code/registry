class CorrespondencesController < ApplicationController
  # GET /correspondences/template
  def template
    render('template', layout: !params[:content].present?)
  end
end

