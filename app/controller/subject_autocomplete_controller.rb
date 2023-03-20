# -*- coding: utf-8 -*-
class SubjectAutocompleteController < ApplicationController

  if Rails::VERSION::MAJOR >= 4
    before_action :find_project, :init
  else
    before_filter :find_project, :init
  end

  def init
    @issue_status_closed = IssueStatus.where('is_closed=?', true).pluck :id
    @issue_status_open = IssueStatus.select('id').where('is_closed=?', false).pluck :id
  end

  def get_matches
    # autocomplete for the issue subject field.
    limit_count = 15
    default_closed_past_days = 30
    # load closed tickets, show issue id
    @issues = []
    q = params[:term].to_s.strip
    if q.present?
      if @project.nil?
        scope = Issue.visible
      else
        if @project.parent
          project_siblings = Project.where(:parent_id => @project.parent.id).map{|e| e.id }
          project_siblings_children = Project.where(:parent_id => project_siblings).map{|e| e.id }
          projects = project_siblings + project_siblings_children << @project.parent[:id]
        else
          project_children = Project.where(:parent_id => @project.id).map{|e| e.id }
          projects = project_children << @project.id
        end
        scope = Issue.where(:project_id => projects).visible
      end
      if q.match(/\A#?(\d+)\z/)
        @issues << scope.find_by_id($1.to_i)
      end
      past_days = params[:closed_past_days] ? params[:closed_past_days].to_i : default_closed_past_days
      time_now = DateTime.now
      # use ruby regexp. not all databases support regexp in sql
      q = q.gsub(/[^a-zA-Z0-9# ]/, "").split(" ").map{|e|
        e = Issue.connection.quote("%#{e}%")
        "lower(#{Issue.table_name}.subject) like #{e}"}.join(" and ")
      @issues += scope
        .where("#{q} and " +
               "(issues.status_id in(?) or (issues.status_id in(?) and issues.updated_on between ? and ?))",
               @issue_status_open, @issue_status_closed, time_now - past_days, time_now)
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
        "issue_url" => url_for(:controller => "issues", :action => "show", :id => e[:id]),
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
