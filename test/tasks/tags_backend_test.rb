require 'test_helper'
require 'rake'

class TagsBackendTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?('tags:backend')
    @task = Rake::Task['tags:backend']
    @task.reenable
    @env = ENV['TAGGING_BACKEND']
    @backend = Rails.configuration.tagging_backend
  end

  teardown do
    ENV['TAGGING_BACKEND'] = @env
    Rails.configuration.tagging_backend = @backend
  end

  test 'keeps the configured backend if TAGGING_BACKEND is unset or blank' do
    [nil, ' '].each do |value|
      ENV['TAGGING_BACKEND'] = value
      @task.reenable
      @task.invoke
      assert_equal(@backend, Rails.configuration.tagging_backend)
    end
  end

  test 'sets the backend from TAGGING_BACKEND' do
    ENV['TAGGING_BACKEND'] = ' Local '
    @task.invoke
    assert_equal(:local, Rails.configuration.tagging_backend)
    assert_equal(TaggingService::LocalBackend, TaggingService.backend)
  end

  test 'aborts on an unknown TAGGING_BACKEND' do
    ENV['TAGGING_BACKEND'] = 'openai'
    _, err = capture_io do
      error = assert_raises(SystemExit) { @task.invoke }
      assert_not(error.success?)
    end
    assert_match(
      'Invalid TAGGING_BACKEND: Unknown tagging backend: openai ' \
        '(expected one of: anthropic, local)',
      err
    )
  end

  test 'is a prerequisite of every tags task' do
    tasks = Rake::Task.tasks.select do |task|
      task.name.start_with?('tags:') && task.name != 'tags:backend'
    end
    assert_not_empty(tasks)
    tasks.each do |task|
      assert_includes(task.prerequisites, 'backend', task.name)
    end
  end
end
