require 'digest'
require 'json'

# Record-and-replay wrapper around a tagging backend, for evaluation
# experiments: the raw proposals of the wrapped backend (before
# TaggingService's post-processing) are stored per request, keyed by a
# digest of the exact system and name prompts. Experiments that only change
# post-processing (rules in TaggingService, excluded bases, implications)
# replay the stored answers without calling the model; any change to the
# prompt changes the key, so the model is called again.
#
# Enabled by setting TAGGING_CACHE to a directory, one per model (the key
# does not include the model). Not meant for production use.
class TaggingService::CachingBackend
  include TaggingService::Prompt

  def self.wrap(backend)
    dir = ENV['TAGGING_CACHE'].presence or return backend

    Class.new(self) do
      define_singleton_method(:inner) { backend }
      define_singleton_method(:dir) { Pathname(dir).tap(&:mkpath) }
      # Replays work without the model server; only cache misses need it
      define_singleton_method(:model_label) do
        label =
          begin
            backend.model_label
          rescue TaggingService::Error
            'backend unavailable, replay only'
          end
        "#{label} (cache: #{File.basename(dir)})"
      end
    end
  end

  def propose(name)
    etym = etymology_text(name)
    key = Digest::SHA256.hexdigest(
      [system_prompt, name_prompt(name, etym)].join("\0")
    )
    file = self.class.dir.join("#{key}.json")
    return JSON.parse(file.read) if file.exist?

    self.class.inner.new.propose(name).tap do |proposals|
      file.write(JSON.generate(proposals))
    end
  end
end
