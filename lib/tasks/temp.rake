# frozen_string_literal: true

namespace :temp do
  # desc 'Create 28 users and register them to tournament ID 5'
  # task create_users_and_register: :environment do
  #   tournament = Tournament::Tournament.find(11)

  #   User.find_each do |user|
  #     Tournament::Registration.create!(
  #       tournament: tournament,
  #       user: user,
  #       status: 'pending'
  #     )

  #     puts "Registered #{user.username} to tournament #{tournament.name}"
  #   end

  #   tournament.reload.registrations.find_each { |participation| participation.update(status: 'checked_in') }
  # end
end
