module HelpTopics
  extend ActiveSupport::Concern

  def help_topics
    {
      tutorial: {
        new_genome: 'I have a genome belonging to a novel taxon, how can I ' \
                    'register it?'
      },
      guide: {
        etymology: 'How do I fill the etymology table?',
        dictionary: 'How do I use dictionary lookups?',
        exceptions: 'When and how do I request a genome quality exception?',
        # SOPs
        curation: 'How are names internally curated?'
      },
      explanation: {
        open_data: 'What data is publicly released and how?',
        authorship: 'Can I submit names I didn\'t author?'
      },
      reference: {
        register: 'What are Register Lists?',
        paths: 'What are the paths to validation?'
      }
    }
  end

  def help_topic_categories
    Hash[
      *help_topics.map { |k, v| v.keys.map { |topic| [topic, k] } }.flatten
    ]
  end
end
