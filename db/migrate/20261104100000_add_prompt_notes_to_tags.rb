class AddPromptNotesToTags < ActiveRecord::Migration[6.1]
  def change
    # Curation instructions for the tagging service, not shown in the UI
    add_column :tags, :prompt_notes, :text
  end
end
