require 'test_helper'
require 'rake'
require 'minitest/mock'

class EvaluateTagsTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?('tags:evaluate')
    @task = Rake::Task['tags:evaluate']
    @task.reenable
    Rake::Task['tags:backend'].reenable
    @tagging_backend_env = ENV.delete('TAGGING_BACKEND')
  end

  teardown do
    ENV['TAGGING_BACKEND'] = @tagging_backend_env
  end

  test 'aborts before evaluating any name if the backend is unavailable' do
    backend = Class.new do
      def self.model_label
        raise TaggingService::Error, 'Local model connection error: refused'
      end

      def self.new
        raise 'No name should be evaluated'
      end
    end

    TaggingService.stub(:backend, backend) do
      _, err = capture_io do
        error = assert_raises(SystemExit) { @task.invoke }
        assert_not(error.success?)
      end
      assert_match(
        'Tagging backend unavailable: Local model connection error', err
      )
    end
  end
end
