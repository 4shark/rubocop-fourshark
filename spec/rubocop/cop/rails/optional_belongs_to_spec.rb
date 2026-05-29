# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Rails::OptionalBelongsTo, :config do
  it 'registers an offense for belongs_to without optional' do
    expect_offense(<<~RUBY)
      belongs_to :user
      ^^^^^^^^^^ Declare `belongs_to` with `optional: true` and validate presence manually.
    RUBY
  end

  it 'registers an offense when optional is false' do
    expect_offense(<<~RUBY)
      belongs_to :user, optional: false
      ^^^^^^^^^^ Declare `belongs_to` with `optional: true` and validate presence manually.
    RUBY
  end

  it 'does not register an offense when optional: true is set' do
    expect_no_offenses(<<~RUBY)
      belongs_to :user, optional: true
    RUBY
  end
end
