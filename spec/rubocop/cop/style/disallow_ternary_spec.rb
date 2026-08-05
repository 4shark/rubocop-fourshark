# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Style::DisallowTernary, :config do
  it 'registers an offense for a ternary assignment' do
    expect_offense(<<~RUBY)
      status = saved ? :applied : :failed
               ^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not use the ternary conditional. Use an explicit `if`/`else` instead.
    RUBY
  end

  it 'registers an offense for a ternary in an argument list' do
    expect_offense(<<~RUBY)
      report(outcome: succeeded ? 'success' : 'failure')
                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not use the ternary conditional. Use an explicit `if`/`else` instead.
    RUBY
  end

  it 'does not register an offense for an explicit if/else' do
    expect_no_offenses(<<~RUBY)
      if saved
        status = :applied
      else
        status = :failed
      end
    RUBY
  end

  it 'does not register an offense for a modifier if' do
    expect_no_offenses(<<~RUBY)
      status = :applied if saved
    RUBY
  end
end
