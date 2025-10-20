class ReportsController < ApplicationController
  before_action(:set_report, only: %i[show])

  # GET /reports/1
  def show
  end

  # GET /reports/genomes/1
  def genome
    @object = Genome.find(params[:id])
    @crumbs = [
      ['Genomes', genomes_url],
      [@genome.title(''), @genome],
      'Reports'
    ]
    render('object', layout: !params[:content].present?)
  end

  private

  def set_report
    @report = Report.find(params[:id])
  end
end

