# -*- coding: utf-8 -*-
class SubjectAutocompleteController < ApplicationController
  before_action :find_project, only: :get_matches

  def get_matches
    # autocomplete for the issue subject field.
    limit_count = 15
    default_closed_past_days = 30

    # load closed tickets, show issue id
    @issues = []
    q = params[:term].to_s.strip
    if q.present?
      scope = Issue.joins(:status, :project).visible

      if @project.present?
        scope = scope.where(@project.project_condition(true))
      end

      if q =~ /\A#?(\d+)\z/
        @issues << scope.find_by(id: ::Regexp.last_match(1).to_i)
      end
      past_days = params[:closed_past_days] ? params[:closed_past_days].to_i : default_closed_past_days

      open_or_closed_in_past_days =
        scope
          .where({ issue_statuses: { is_closed: true } })
          .where(
            Issue.sanitize_sql_for_assignment(["issues.updated_on between ? and ?", past_days.days.ago, Time.current])
          ).or(scope.open)

      @issues += scope
        .like(q)
        .and(open_or_closed_in_past_days)
        .order("#{Issue.table_name}.id desc")
        .limit(limit_count)
      @issues.compact!
      versions = {}
      Version.select("id,name").each{|e| versions[e.id] = e.name }
    end

    render :json => @issues.map {|e|
      label = "##{e[:id]} #{e[:subject]}"
      if e.fixed_version_id then label = "#{versions[e.fixed_version_id]} » #{label}" end

      {
        "label" => label,
        "value" => "",
        "issue_url" => issue_path(e),
        "is_closed" => e.closed?
      }
    }
  end

  private

  def find_project
    return if params[:project_id].blank?

    @project = Project.find(params[:project_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
end
