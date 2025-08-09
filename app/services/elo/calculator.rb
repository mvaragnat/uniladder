# frozen_string_literal: true

module Elo
  class Calculator
    START_RATING = 1200
    K_FACTOR = 30

    def expected_score(my_rating, opp_rating)
      1.0 / (1.0 + (10.0**((opp_rating - my_rating) / 400.0)))
    end

    def delta(score:, expected:, k_factor: K_FACTOR)
      (k_factor * (score - expected)).round
    end
  end
end
