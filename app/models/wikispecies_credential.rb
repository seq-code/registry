class WikispeciesCredential < ApplicationRecord
  belongs_to :user

  def self.encryptor
    ActiveSupport::MessageEncryptor.new(
      ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base)
        .generate_key('wikispecies_credential', 32)
    )
  end

  def access_token
    self.class.encryptor.decrypt_and_verify(encrypted_access_token)
  end

  def access_token=(value)
    self.encrypted_access_token = self.class.encryptor.encrypt_and_sign(value)
  end

  def refresh_token
    return nil unless encrypted_refresh_token

    self.class.encryptor.decrypt_and_verify(encrypted_refresh_token)
  end

  def refresh_token=(value)
    self.encrypted_refresh_token =
      value ? self.class.encryptor.encrypt_and_sign(value) : nil
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end
end
