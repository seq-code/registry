require 'test_helper'
require 'rake'
require 'minitest/mock'

class TagNamesTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?('tags:propose')
    @task = Rake::Task['tags:propose']
    @task.reenable
    @env = ENV.to_h.slice('LIMIT', 'RANK', 'DRY_RUN')
    ENV['LIMIT'] = '1'
    ENV['RANK'] = 'genus'
    ENV.delete('DRY_RUN')
  end

  teardown do
    %w[LIMIT RANK DRY_RUN].each { |key| ENV[key] = @env[key] }
  end

  test 'aborts before processing any name if the backend is unavailable' do
    backend = Class.new do
      def self.model_label
        raise TaggingService::Error, 'Local model connection error: refused'
      end

      def self.new
        raise 'No name should be processed'
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

  test 'records the model in the notes of the proposals' do
    backend = Class.new do
      def self.model_label
        'test-model.gguf'
      end

      def propose(_name)
        [{ 'slug' => 'eponym', 'confidence' => 'high', 'basis' => 'Someone' }]
      end
    end

    before = NameTag.pluck(:id)
    out, = TaggingService.stub(:backend, backend) do
      capture_io { @task.invoke }
    end
    assert_match(/^Model: test-model\.gguf$/, out)

    # The proposal and the tags it implies (e.g., commemorative)
    created = NameTag.where.not(id: before).includes(:tag).to_a
    assert_includes(created.map { |nt| nt.tag.slug }, 'eponym')
    created.each do |name_tag|
      assert_equal('llm', name_tag.proposed_by)
      assert_match(/; model: test-model\.gguf\z/, name_tag.notes)
    end
    assert_equal(
      'high', created.find { |nt| nt.tag.slug == 'eponym' }.confidence
    )
  end
end
