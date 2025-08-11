# frozen_string_literal: true

module ApplicationHelper
  # Renders an SVG bracket for elimination tournaments.
  # Uses parent/child relations; no fallback to rounds.
  def render_svg_bracket(tournament, _rounds)
    elim_matches = tournament.matches.where(tournament_round_id: nil)
    if elim_matches.none?
      return content_tag(:p, t('tournaments.show.no_rounds', default: 'No rounds yet'), class: 'card-date')
    end

    # Compute depth to root for each match
    depth_cache = {}
    compute_depth = lambda do |m|
      return depth_cache[m.id] if depth_cache.key?(m.id)

      d = 0
      cur = m
      while cur.parent_match
        d += 1
        cur = cur.parent_match
      end
      depth_cache[m.id] = d
    end
    elim_matches.each { |m| compute_depth.call(m) }

    max_depth = depth_cache.values.max || 0

    # Build levels with leaves at level 0, root at level max_depth
    levels = Array.new(max_depth + 1) { [] }
    elim_matches.includes(:a_user, :b_user, :child_matches, :parent_match).order(:created_at).each do |m|
      level = max_depth - depth_cache[m.id]
      levels[level] << m
    end

    # Prepare seeding (for debug labels)
    seed_map = build_seed_map_for(tournament)

    # Layout constants
    cell_w = 240
    cell_h = 68
    col_gap = 120
    row_gap = 36
    padding = 24
    elbow = 28

    # Compute x positions per level
    x_for_level = ->(lvl) { padding + (lvl * (cell_w + col_gap)) }

    # Compute y positions: leaves placed sequentially; parents centered between children
    positions = {}

    # Leaves
    leaves = levels[0]
    leaves.each_with_index do |m, idx|
      positions[m.id] = { x: x_for_level.call(0), y: padding + (idx * (cell_h + row_gap)) }
    end

    # Upper levels
    (1..max_depth).each do |lvl|
      levels[lvl].each do |m|
        kids = m.child_matches.order(:created_at).to_a
        centers = kids.map do |ch|
          pos = positions[ch.id]
          pos ? (pos[:y] + (cell_h / 2)) : nil
        end.compact

        center_y = if centers.any?
                     (centers.sum.to_f / centers.size)
                   else
                     # Fallback if children unknown: stack
                     padding + (levels[lvl].index(m) * (cell_h + row_gap))
                   end

        positions[m.id] = { x: x_for_level.call(lvl), y: (center_y - (cell_h / 2)).round }
      end
    end

    # Compute overall width/height from positions actually used
    col_count = levels.size
    # rubocop:disable Rails/Pluck
    max_y = positions.values.map { |p| p[:y] }.max || 0
    # rubocop:enable Rails/Pluck
    height = (max_y + cell_h + padding)
    width = padding + (col_count * cell_w) + ((col_count - 1) * col_gap)

    admin = Current.user && tournament.creator_id == Current.user.id

    content_tag(:div, style: 'overflow-x:auto; -webkit-overflow-scrolling:touch;') do
      content_tag(:svg, width: width, height: height + 20, style: 'display:block;') do
        header_labels = levels.each_with_index.map do |_matches, c|
          x = x_for_level.call(c) + (cell_w / 2)
          content_tag(:text, round_label_for_column(c, col_count), x: x, y: padding - 6, 'text-anchor': 'middle',
                                                                   'font-size': 12, fill: '#6b7280')
        end

        # Elbow connectors
        elbows = elim_matches.flat_map do |m|
          from = positions[m.id]
          next [] unless from

          parent_center_y = from[:y] + (cell_h / 2)
          m.child_matches.map do |child|
            to = positions[child.id]
            next nil unless to

            child_center_y = to[:y] + (cell_h / 2)
            x1 = to[:x] + cell_w
            hx = from[:x] - elbow
            [
              content_tag(:line, nil, x1: x1, y1: child_center_y, x2: hx, y2: child_center_y, stroke: '#cbd5e1',
                                      'stroke-width': 2),
              content_tag(:line, nil, x1: hx, y1: child_center_y, x2: hx, y2: parent_center_y, stroke: '#cbd5e1',
                                      'stroke-width': 2),
              content_tag(:line, nil, x1: hx, y1: parent_center_y, x2: from[:x], y2: parent_center_y,
                                      stroke: '#cbd5e1', 'stroke-width': 2)
            ]
          end.compact
        end

        # Match boxes
        boxes = elim_matches.map do |m|
          pos = positions[m.id]
          next nil unless pos

          # Names with BYE logic: if leaf with a single player, display 'bye' instead of 'TBD'
          a_set = m.a_user_id.present?
          b_set = m.b_user_id.present?
          a_bye = !a_set && b_set && m.child_matches.empty?
          b_bye = a_set && !b_set && m.child_matches.empty?

          a_name = if a_set
                     m.a_user.username
                   elsif a_bye
                     'bye'
                   else
                     'TBD'
                   end
          b_name = if b_set
                     m.b_user.username
                   elsif b_bye
                     'bye'
                   else
                     'TBD'
                   end

          a_seed = m.a_user_id && seed_map[m.a_user_id] ? "(S#{seed_map[m.a_user_id]})" : ''
          b_seed = m.b_user_id && seed_map[m.b_user_id] ? "(S#{seed_map[m.b_user_id]})" : ''

          if m.game_event_id
            pa = m.game_event.game_participations.find_by(user: m.a_user)
            pb = m.game_event.game_participations.find_by(user: m.b_user)
            a_style = pa&.score.to_i > pb&.score.to_i ? 'font-weight:700; fill:#16a34a;' : ''
            b_style = pb&.score.to_i > pa&.score.to_i ? 'font-weight:700; fill:#16a34a;' : ''
            score_text = "#{pa&.score} - #{pb&.score}"
            link = nil
          else
            a_style = ''
            b_style = ''
            score_text = t('tournaments.show.pending', default: 'Pending')
            both_present = m.a_user_id.present? && m.b_user_id.present?
            allowed = both_present && (admin || [m.a_user_id, m.b_user_id].compact.include?(Current.user&.id))
            link = allowed ? tournament_tournament_match_path(tournament, m) : nil
          end

          parts = [
            content_tag(:rect, nil, x: pos[:x], y: pos[:y], width: cell_w, height: cell_h, rx: 10, ry: 10,
                                    fill: '#ffffff', stroke: '#e5e7eb', 'stroke-width': 3),
            content_tag(:text, [a_name, a_seed].compact_blank.join(' '), x: pos[:x] + 14, y: pos[:y] + 26,
                                                                         style: a_style, 'font-size': 14),
            content_tag(:text, [b_name, b_seed].compact_blank.join(' '), x: pos[:x] + 14, y: pos[:y] + 50,
                                                                         style: b_style, 'font-size': 14),
            content_tag(:text, score_text, x: pos[:x] + cell_w - 14, y: pos[:y] + 38, 'text-anchor': 'end',
                                           'font-size': 14, fill: '#6b7280')
          ]

          if link
            # rubocop:disable Layout/LineLength
            parts << content_tag(:a,
                                 content_tag(:text, t('tournaments.open'), x: pos[:x] + cell_w - 14, y: pos[:y] + 60, 'text-anchor': 'end', 'font-size': 12, fill: '#2563eb'), href: link)
            # rubocop:enable Layout/LineLength
          end

          safe_join(parts)
        end.compact

        safe_join([header_labels, elbows, boxes].flatten)
      end
    end
  end

  private

  def round_label_for_column(index, total)
    return 'Final' if index == total - 1
    return 'Semifinal' if index == total - 2
    return 'Quarterfinal' if index == total - 3

    "R#{index + 1}"
  end

  def build_seed_map_for(tournament)
    users = tournament.participants.to_a
    system = tournament.game_system
    seeded = users.map do |u|
      rating = EloRating.find_by(user: u, game_system: system)&.rating || EloRating::START_RATING
      [u.id, rating]
    end
    seeded.sort_by! { |(_id, rating)| -rating }
    seeded.to_h { |uid, rating| [uid, seeded.index([uid, rating]) + 1] }
  end
end
