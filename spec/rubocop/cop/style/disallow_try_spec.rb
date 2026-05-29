# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Style::DisallowTry, :config do
  it 'registers an offense for try' do
    expect_offense(<<~RUBY)
      user.try(:name)
      ^^^^^^^^^^^^^^^ Do not use `try` or `try!`. Use explicit conditionals instead.
    RUBY
  end

  it 'registers an offense for try!' do
    expect_offense(<<~RUBY)
      user.try!(:name)
      ^^^^^^^^^^^^^^^^ Do not use `try` or `try!`. Use explicit conditionals instead.
    RUBY
  end

  it 'does not register an offense for a direct method call' do
    expect_no_offenses(<<~RUBY)
      user.name
    RUBY
  end
end
