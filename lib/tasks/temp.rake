# frozen_string_literal: true

namespace :temp do
  desc 'Create 28 users and register them to tournament ID 5'
  task create_users_and_register: :environment do
    tournament = Tournament::Tournament.find(6)

    28.times do |i|
      user_number = i + 4

      # user = User.create!(
      #   username: "user#{user_number}",
      #   email_address: "user#{user_number}@test.com",
      #   password: "password#{user_number}",
      #   name: "User #{user_number}"
      # )
      user = User.find(user_number)

      Tournament::Registration.create!(
        tournament: tournament,
        user: user,
        status: 'checked_in'
      )

      puts "Created user #{user.username} and registered to tournament #{tournament.name}"
    end

    puts "Successfully created 28 users and registered them to tournament ID #{tournament.id}"
  end
end
