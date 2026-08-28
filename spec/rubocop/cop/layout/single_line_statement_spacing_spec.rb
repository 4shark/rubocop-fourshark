# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Layout::SingleLineStatementSpacing, :config do
  it 'registers an offense and removes the blank line between two single-line statements' do
    expect_offense(<<~RUBY)
      foo

      bar
      ^^^ Remove the blank line between consecutive single-line statements.
    RUBY

    expect_correction(<<~RUBY)
      foo
      bar
    RUBY
  end

  it 'removes multiple blank lines between two single-line statements' do
    expect_offense(<<~RUBY)
      foo


      bar
      ^^^ Remove the blank line between consecutive single-line statements.
    RUBY

    expect_correction(<<~RUBY)
      foo
      bar
    RUBY
  end

  it 'keeps the blank line that separates code from a following comment' do
    expect_no_offenses(<<~RUBY)
      foo

      # note
      bar
    RUBY
  end

  it 'keeps the blank line that separates a comment from the following code' do
    expect_no_offenses(<<~RUBY)
      foo
      # note

      bar
    RUBY
  end

  it 'removes the blank line between two consecutive comments' do
    expect_offense(<<~RUBY)
      foo
      # one

      # two
      bar
      ^^^ Remove the blank line between consecutive single-line statements.
    RUBY

    expect_correction(<<~RUBY)
      foo
      # one
      # two
      bar
    RUBY
  end

  it 'accepts adjacent single-line statements with no blank line' do
    expect_no_offenses(<<~RUBY)
      foo
      bar
    RUBY
  end

  it 'ignores a blank line next to a multi-line statement' do
    expect_no_offenses(<<~RUBY)
      foo(
        bar
      )

      baz
    RUBY
  end

  it 'ignores a blank line before a multi-line statement' do
    expect_no_offenses(<<~RUBY)
      baz

      foo(
        bar
      )
    RUBY
  end

  it 'removes the blank line in every offending pair of a run' do
    expect_offense(<<~RUBY)
      foo

      bar
      ^^^ Remove the blank line between consecutive single-line statements.

      baz
      ^^^ Remove the blank line between consecutive single-line statements.
    RUBY

    expect_correction(<<~RUBY)
      foo
      bar
      baz
    RUBY
  end

  it 'ignores the blank line after a guard clause' do
    expect_no_offenses(<<~RUBY)
      return if foo

      bar
    RUBY
  end

  it 'ignores the blank line before a bare return' do
    expect_no_offenses(<<~RUBY)
      foo

      return
    RUBY
  end

  it 'ignores the blank line before a bare next' do
    expect_no_offenses(<<~RUBY)
      foo

      next
    RUBY
  end

  it 'ignores the blank line around a raise' do
    expect_no_offenses(<<~RUBY)
      foo

      raise 'boom'
    RUBY
  end

  it 'ignores the blank line before an access modifier' do
    expect_no_offenses(<<~RUBY)
      alias foo bar

      private
    RUBY
  end

  it 'ignores a blank line between statements that carry a heredoc' do
    expect_no_offenses(<<~RUBY)
      foo(<<~TEXT)
        hi
      TEXT

      bar
    RUBY
  end
end
