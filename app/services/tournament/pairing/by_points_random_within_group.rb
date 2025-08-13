# frozen_string_literal: true

module Tournament
  module Pairing
    class ByPointsRandomWithinGroup
      Result = Struct.new(:pairs) # pairs: array of [user_a, user_b]

      def initialize(tournament)
        @tournament = tournament
      end

      def call
        users = eligible_users
        return Result.new([]) if users.size < 2

        points_map = current_points
        grouped = users.group_by { |u| points_map[u.id] || 0.0 }

        # Pair each group independently, randomizing order within score group
        rng = Random.new(seed_for_round)
        pairs = []
        leftover = []

        grouped.keys.sort.reverse_each do |score|
          group = grouped[score].shuffle(random: rng)
          grp_pairs, grp_leftover = pair_group(group, rng)
          pairs.concat(grp_pairs)
          leftover.concat(grp_leftover)
        end

        # Pair any leftover across adjacent groups (randomized)
        leftover = leftover.shuffle(random: rng)
        cross_pairs, = pair_group(leftover, rng)
        pairs.concat(cross_pairs)

        # If still one leftover, unavoidable bye (ignore for now)
        Result.new(pairs)
      end

      private

      attr_reader :tournament

      # Users who are checked in if any, else all registered
      def eligible_users
        regs = tournament.registrations.includes(:user)
        checked = regs.select { |r| r.status == 'checked_in' }.map(&:user)
        return checked if checked.any?

        regs.map(&:user)
      end

      def current_points
        points = Hash.new(0.0)
        tournament.matches.includes(:a_user, :b_user).find_each do |m|
          next if m.result == 'pending'
          next unless m.a_user && m.b_user

          case m.result
          when 'a_win'
            points[m.a_user.id] += 1.0
          when 'b_win'
            points[m.b_user.id] += 1.0
          when 'draw'
            points[m.a_user.id] += 0.5
            points[m.b_user.id] += 0.5
          end
        end
        points
      end

      def seed_for_round
        # Basic deterministic seed: round count + tournament id
        (tournament.rounds.maximum(:number) || 0) + tournament.id
      end

      def pair_group(group_users, _rng)
        pairs = []
        leftover = group_users.dup

        # Greedy: try pairing avoiding repeats
        used = []
        while leftover.size >= 2
          a = leftover.shift
          partner_idx = leftover.find_index { |b| !already_played?(a, b) }
          partner_idx ||= 0 # fallback to first (repeat allowed only if needed)
          b = leftover.delete_at(partner_idx)
          pairs << [a, b]
          used.push(a, b)
        end

        [pairs, leftover]
      end

      def already_played?(a_user, b_user)
        tournament.matches.where(a_user: a_user, b_user: b_user).or(
          tournament.matches.where(a_user: b_user, b_user: a_user)
        ).exists?
      end
    end
  end
end
