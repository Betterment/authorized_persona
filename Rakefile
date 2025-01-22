# frozen_string_literal: true

require "bundler/gem_tasks"

require 'rubocop/rake_task'
RuboCop::RakeTask.new

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)

def default_task
  if ENV['APPRAISAL_INITIALIZED'] || ENV['CI']
    %i(rubocop spec)
  else
    require 'appraisal'
    Appraisal::Task.new
    %i(appraisal)
  end
end

task(:default).clear.enhance(default_task)
