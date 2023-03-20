# -*- coding: utf-8 -*-
module RedmineSubjectAutocomplete
  class Hooks < Redmine::Hook::ViewListener
    def view_issues_form_details_bottom(context)

      path = url_for({controller: 'subject_autocomplete', action: 'get_matches', project_id: context.try(:[], :project).try(:[], :id)})
      translations = {
        "placeholder_text" => I18n.translate(:placeholder_text)
      }
      javascript_tag("var subjectAutocomplete = {get_matches_path: \"#{escape_javascript path}\", translations: #{translations.to_json}}") +
        javascript_include_tag('main', :plugin => 'redmine_subject_autocomplete')
    end
  end
end
