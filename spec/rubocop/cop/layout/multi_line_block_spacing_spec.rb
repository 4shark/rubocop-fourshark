# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Layout::MultiLineBlockSpacing, :config do
  it 'registers an offense when a single-line statement follows a multi-line one without a blank' do
    expect_offense(<<~RUBY)
      foo(
        bar
      )
      baz
      ^^^ Add a blank line around multi-line statements.
    RUBY
  end

  it 'accepts a blank line after a multi-line statement' do
    expect_no_offenses(<<~RUBY)
      foo(
        bar
      )

      baz
    RUBY
  end

  it 'accepts adjacent single-line statements with no blank' do
    expect_no_offenses(<<~RUBY)
      foo
      bar
    RUBY
  end
end
