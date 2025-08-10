# frozen_string_literal: true

module ApplicationHelper
  # Renders an SVG bracket for elimination tournaments.
  # Assumes rounds in order and each match belongs to a round.
  def render_svg_bracket(tournament, rounds)
    unless rounds.present?
      return content_tag(:p, t('tournaments.show.no_rounds', default: 'No rounds yet'), class: 'card-date')
    end

    # Normalize rounds data to array of arrays of matches
    cols = rounds.map { |r| r.matches.includes(:a_user, :b_user).to_a }
    col_count = cols.size
    row_count = cols.map(&:size).max || 0

    cell_w = 220
    cell_h = 60
    col_gap = 80
    row_gap = 30
    padding = 20

    width = (padding * 2) + (col_count * cell_w) + ((col_count - 1) * col_gap)
    height = (padding * 2) + (row_count * (cell_h + row_gap))

    # Compute positions per match: in column c, rows are spaced
    positions = {}
    cols.each_with_index do |matches, c|
      matches.each_with_index do |m, r|
        x = padding + (c * (cell_w + col_gap))
        y = padding + (r * (cell_h + row_gap))
        positions[m.id] = { x: x, y: y }
      end
    end

    admin = Current.user && tournament.creator_id == Current.user.id

    content_tag(:svg, width: width, height: height, style: 'max-width:100%; height:auto;') do
      safe_join([
        # Edges between winners (best-effort if next round exists at same index/2)
        (0...(col_count - 1)).flat_map do |c|
          from_matches = cols[c]
          to_matches = cols[c + 1]
          from_matches.each_with_index.map do |m, i|
            next_idx = i / 2
            next unless to_matches[next_idx]

            from = positions[m.id]
            to = positions[to_matches[next_idx].id]
            x1 = from[:x] + cell_w
            y1 = from[:y] + (cell_h / 2)
            x2 = to[:x]
            y2 = to[:y] + (cell_h / 2)
            content_tag(:line, nil, x1: x1, y1: y1, x2: x2, y2: y2, stroke: '#cbd5e1', 'stroke-width': 2)
          end
        end,
        # Match boxes
        cols.flatten.map do |m|
          pos = positions[m.id]
          a_name = m.a_user.username
          b_name = m.b_user.username
          if m.game_event_id
            pa = m.game_event.game_participations.find_by(user: m.a_user)
            pb = m.game_event.game_participations.find_by(user: m.b_user)
            a_style = pa.score.to_i > pb.score.to_i ? 'font-weight:700; fill:#16a34a;' : ''
            b_style = pb.score.to_i > pa.score.to_i ? 'font-weight:700; fill:#16a34a;' : ''
            score_text = "#{pa&.score} - #{pb&.score}"
            link = nil
          else
            a_style = ''
            b_style = ''
            score_text = t('tournaments.show.pending', default: 'Pending')
            allowed = admin || [m.a_user_id, m.b_user_id].include?(Current.user&.id)
            link = allowed ? tournament_tournament_match_path(tournament, m) : nil
          end

          parts = [
            content_tag(:rect, nil, x: pos[:x], y: pos[:y], width: cell_w, height: cell_h, rx: 8, ry: 8,
                                    fill: '#ffffff', stroke: '#e5e7eb', 'stroke-width': 3),
            content_tag(:text, a_name, x: pos[:x] + 12, y: pos[:y] + 22, style: a_style, 'font-size': 14),
            content_tag(:text, b_name, x: pos[:x] + 12, y: pos[:y] + 44, style: b_style, 'font-size': 14),
            content_tag(:text, score_text, x: pos[:x] + cell_w - 12, y: pos[:y] + 34, 'text-anchor': 'end',
                                           'font-size': 14, fill: '#6b7280')
          ]

          if link
            parts << content_tag(:a,
                                 content_tag(:text, t('tournaments.open'), x: pos[:x] + cell_w - 12, y: pos[:y] + 54, 'text-anchor': 'end', 'font-size': 12, fill: '#2563eb'), href: link)
          end

          safe_join(parts)
        end
      ].flatten)
    end
  end
end
