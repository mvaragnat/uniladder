# frozen_string_literal: true

module Tournament
  module Pairing
    class ByPointsRandomWithinGroup
      Result = Struct.new(:pairs, :bye_user) # pairs: array of [user_a, user_b]

      def initialize(tournament)
        @tournament = tournament
      end

      def call
        users = eligible_users
        return Result.new([], nil) if users.size < 2

        rng = Random.new(seed_for_round)

        # Points including previous byes
        points_map = current_points

        # Optionally pick a bye up-front from the lowest-points group to avoid
        # breaking already-formed pairs later. Avoid assigning a bye to the same
        # player twice in the same tournament when possible.
        bye_user = nil
        if users.size.odd?
          bye_user = select_bye_user(users, points_map, rng)
          users -= [bye_user]
        end

        grouped, scores_desc = group_users_by_points(users, points_map)
        pairs = build_pairs_across_groups(grouped, scores_desc, rng)

        Result.new(pairs, bye_user)
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
          # Count wins including byes (one-sided matches)
          case m.result
          when 'a_win'
            points[m.a_user_id] += 1.0 if m.a_user_id
          when 'b_win'
            points[m.b_user_id] += 1.0 if m.b_user_id
          when 'draw'
            # Only count draw if both players present
            if m.a_user_id && m.b_user_id
              points[m.a_user_id] += 0.5
              points[m.b_user_id] += 0.5
            end
          end
        end
        points
      end

      def users_with_bye_ids
        ids = []
        tournament.matches.find_each do |m|
          next unless %w[a_win b_win].include?(m.result)

          ids << m.a_user_id if m.a_user_id && m.b_user_id.nil? && m.result == 'a_win'
          ids << m.b_user_id if m.b_user_id && m.a_user_id.nil? && m.result == 'b_win'
        end
        ids.compact.uniq
      end

      def select_bye_user(all_users, points_map, rng)
        bye_already = users_with_bye_ids

        # Build groups ascending by points (lowest rank first)
        grouped = all_users.group_by { |u| points_map[u.id] || 0.0 }
        scores_asc = grouped.keys.sort

        candidate = nil
        scores_asc.each do |score|
          group = grouped[score]
          # Prefer those without a previous bye
          eligible = group.reject { |u| bye_already.include?(u.id) }
          pool = eligible.any? ? eligible : group
          next if pool.empty?

          candidate = pool.sample(random: rng)
          break
        end

        candidate
      end

      def seed_for_round
        # Basic deterministic seed: round count + tournament id
        (tournament.rounds.maximum(:number) || 0) + tournament.id
      end

      def group_users_by_points(users, points_map)
        grouped = users.group_by { |u| points_map[u.id] || 0.0 }
        scores_desc = grouped.keys.sort.reverse
        [grouped, scores_desc]
      end

      def build_pairs_across_groups(grouped, scores_desc, rng)
        pairs = []
        scores_desc.each_with_index do |score, idx|
          group = (grouped[score] || []).shuffle(random: rng)

          if group.size.odd? && idx < (scores_desc.size - 1)
            grp_pairs, grp_leftover = pair_group(group, rng)
            pairs.concat(grp_pairs)

            floater = grp_leftover.first
            partner, partner_group_score = find_partner_for_floater(floater, grouped, scores_desc, idx)

            if partner
              grouped[partner_group_score].delete(partner)
              pairs << [floater, partner]
            else
              # Should not happen given even total after bye removal, but keep safe
              grouped[score] = []
            end
          else
            grp_pairs, = pair_group(group, rng)
            pairs.concat(grp_pairs)
          end
        end
        pairs
      end

      def find_partner_for_floater(floater, grouped, scores_desc, current_idx)
        ((current_idx + 1)...scores_desc.size).each do |j|
          lower_score = scores_desc[j]
          lower_group = grouped[lower_score] || []
          next if lower_group.empty?

          candidate = lower_group.find { |u| !already_played?(floater, u) }
          candidate ||= lower_group.first

          return [candidate, lower_score] if candidate
        end
        [nil, nil]
      end

      def pair_group(group_users, _rng)
        pairs = []
        leftover = group_users.dup

        # Greedy: try pairing avoiding repeats
        while leftover.size >= 2
          a = leftover.shift
          partner_idx = leftover.find_index { |b| !already_played?(a, b) }
          partner_idx ||= 0 # fallback to first (repeat allowed only if needed)
          b = leftover.delete_at(partner_idx)
          pairs << [a, b]
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
