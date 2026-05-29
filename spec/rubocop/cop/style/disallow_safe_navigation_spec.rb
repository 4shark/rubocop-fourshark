# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Style::DisallowSafeNavigation, :config do
  it 'registers an offense for safe navigation' do
    expect_offense(<<~RUBY)
      user&.name
      ^^^^^^^^^^ Do not use safe navigation (`&.`). Use explicit conditionals instead.
    RUBY
  end

  it 'does not register an offense for an explicit conditional' do
    expect_no_offenses(<<~RUBY)
      user.name if user
    RUBY
  end
end
