class ReminderMail < ApplicationRecord
  class << self
    def register_reminder
      users =
        User.joins(:registers)
            .where(registers: { notified: false })
            .distinct!

      users.each do |user|
        registers =
          user.registers.select do |register|
            !register.validated? && (register.updated_at < 1.month.ago) && (
              !register.submitted? ||
              (!register.notified? && register.all_endorsed?)
            )
          end

        unless registers.empty?
          AdminMailer.with(user: user, registers: registers)
                     .register_reminder_email
                     .deliver_later
        end
      end
    end
  end
end
