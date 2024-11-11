class GenomeSequencingExperiment < ApplicationRecord
  belongs_to :genome
  belongs_to :sequencing_experiment
end
