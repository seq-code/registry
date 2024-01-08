class CreateNotifications < ActiveRecord::Migration[6.1]
  def change
    create_table :notifications do |t|
      t.boolean :seen, default: false
      t.boolean :notified_email, default: false
      t.references :user, null: false, foreign_key: true
      t.references :notifiable, polymorphic: true, null: false
      t.references :linkeable, polymorphic: true, default: nil
      t.string :action, default: nil

      t.timestamps
    end
  end
end
