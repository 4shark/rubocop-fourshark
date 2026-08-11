# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Layout::EmptyLineBeforeGuardClause, :config do
  it 'registers an offense when a guard clause follows ordinary code without a blank' do
    expect_offense(<<~RUBY)
      def foo
        bar
        return if baz?
        ^^^^^^^^^^^^^^ Add a blank line before the guard clause.

        qux
      end
    RUBY
  end

  it 'registers an offense for the first clause of a run that follows ordinary code' do
    expect_offense(<<~RUBY)
      def foo
        bar
        return if baz?
        ^^^^^^^^^^^^^^ Add a blank line before the guard clause.
        return if qux?

        corge
      end
    RUBY
  end

  it 'registers an offense when a `next` guard clause follows ordinary code without a blank' do
    expect_offense(<<~RUBY)
      items.each do |item|
        bar
        next if item.blank?
        ^^^^^^^^^^^^^^^^^^^ Add a blank line before the guard clause.

        qux
      end
    RUBY
  end

  it 'accepts a guard clause separated from the code above it' do
    expect_no_offenses(<<~RUBY)
      def foo
        bar

        return if baz?

        qux
      end
    RUBY
  end

  it 'accepts a run of guard clauses with no blank lines between them' do
    expect_no_offenses(<<~RUBY)
      def foo
        return if baz?
        return if qux?
        next if corge?

        bar
      end
    RUBY
  end

  it 'accepts a guard clause that opens the body' do
    expect_no_offenses(<<~RUBY)
      def foo
        return if baz?

        bar
      end
    RUBY
  end

  it 'accepts a guard clause as the only statement in the body' do
    expect_no_offenses(<<~RUBY)
      def foo
        return if baz?
      end
    RUBY
  end

  it 'accepts a guard clause whose comment carries the blank line above it' do
    expect_no_offenses(<<~RUBY)
      def foo
        bar

        # why this one leaves early
        return if baz?

        qux
      end
    RUBY
  end

  it 'accepts a conditional that is not a guard clause' do
    expect_no_offenses(<<~RUBY)
      def foo
        bar
        baz if qux?

        corge
      end
    RUBY
  end
end
