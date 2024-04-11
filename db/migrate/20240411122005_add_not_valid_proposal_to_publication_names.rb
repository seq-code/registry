class AddNotValidProposalToPublicationNames < ActiveRecord::Migration[6.1]
  def change
    add_column :publication_names, :not_valid_proposal, :boolean, default: false
  end
end
