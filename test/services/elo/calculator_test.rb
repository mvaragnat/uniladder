# frozen_string_literal: true

require 'test_helper'

class EloCalculatorTest < ActiveSupport::TestCase
  def setup
    @calc = Elo::Calculator.new
  end

  test 'expected score symmetry sums to 1' do
    a = 1500
    b = 1700
    ea = @calc.expected_score(a, b)
    eb = @calc.expected_score(b, a)
    assert_in_delta 1.0, ea + eb, 1e-9
  end

  test 'delta positive when score exceeds expected' do
    expected = 0.25
    delta = @calc.delta(score: 1.0, expected: expected)
    assert_operator delta, :>, 0
  end

  test 'delta negative when score below expected' do
    expected = 0.75
    delta = @calc.delta(score: 0.0, expected: expected)
    assert_operator delta, :<, 0
  end

  test 'k factor is 30 by default' do
    ea = @calc.expected_score(1500, 1700)
    delta = @calc.delta(score: 1.0, expected: ea)
    # should equal 30 * (1 - ea), rounded
    assert_equal (30 * (1.0 - ea)).round, delta
  end
end
