namespace :temp do
  desc 'Create 28 users and register them to tournament ID 5'
  task create_users_and_register: :environment do
    tournament = Tournament::Tournament.find(5)

    28.times do |i|
      user_number = i + 4

      user = User.create!(
        username: "user#{user_number}",
        email_address: "user#{user_number}@test.com",
        password: "password#{user_number}",
        name: "User #{user_number}"
      )

      Tournament::Registration.create!(
        tournament: tournament,
        user: user,
        status: 'pending'
      )

      puts "Created user #{user.username} and registered to tournament #{tournament.name}"
    end

    puts "Successfully created 28 users and registered them to tournament ID #{tournament.id}"
  end

  desc 'Check in all registrations for tournament ID 5'
  task check_in_registrations: :environment do
    tournament = Tournament::Tournament.find(5)

    registrations = tournament.registrations.where(status: 'pending')

    if registrations.empty?
      puts "No pending registrations found for tournament #{tournament.name}"
      return
    end

    checked_in_count = 0

    registrations.find_each do |registration|
      registration.update!(status: 'checked_in')
      checked_in_count += 1
      puts "Checked in user: #{registration.user.username}"
    end

    puts "Successfully checked in #{checked_in_count} registrations for tournament #{tournament.name}"
  end
end
