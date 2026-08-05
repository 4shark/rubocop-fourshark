# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Style::DisallowDelegate, :config do
  it 'registers an offense for delegate' do
    expect_offense(<<~RUBY)
      delegate :name, to: :user
      ^^^^^^^^^^^^^^^^^^^^^^^^^ Do not use automatic delegation. Write the method explicitly instead.
    RUBY
  end

  it 'registers an offense for delegate_missing_to' do
    expect_offense(<<~RUBY)
      delegate_missing_to :user
      ^^^^^^^^^^^^^^^^^^^^^^^^^ Do not use automatic delegation. Write the method explicitly instead.
    RUBY
  end

  it 'registers an offense for def_delegator' do
    expect_offense(<<~RUBY)
      def_delegator :@user, :name
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not use automatic delegation. Write the method explicitly instead.
    RUBY
  end

  it 'registers an offense for def_delegators' do
    expect_offense(<<~RUBY)
      def_delegators :@user, :name, :email
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not use automatic delegation. Write the method explicitly instead.
    RUBY
  end

  it 'registers an offense for DelegateClass' do
    expect_offense(<<~RUBY)
      DelegateClass(User)
      ^^^^^^^^^^^^^^^^^^^ Do not use automatic delegation. Write the method explicitly instead.
    RUBY
  end

  it 'does not register an offense for a same-named call with a receiver' do
    expect_no_offenses(<<~RUBY)
      event.delegate(:approve)
    RUBY
  end

  it 'does not register an offense for an explicit method' do
    expect_no_offenses(<<~RUBY)
      def name
        user.name
      end
    RUBY
  end
end
