# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Style::DisallowDelegate, :config do
  it 'registers an offense for delegate' do
    expect_offense(<<~RUBY)
      delegate :name, to: :user
      ^^^^^^^^^^^^^^^^^^^^^^^^^ Do not use automatic delegation. Delete the forwarder and let the caller navigate.
    RUBY
  end

  it 'registers an offense for delegate_missing_to' do
    expect_offense(<<~RUBY)
      delegate_missing_to :user
      ^^^^^^^^^^^^^^^^^^^^^^^^^ Do not use automatic delegation. Delete the forwarder and let the caller navigate.
    RUBY
  end

  it 'registers an offense for def_delegator' do
    expect_offense(<<~RUBY)
      def_delegator :@user, :name
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not use automatic delegation. Delete the forwarder and let the caller navigate.
    RUBY
  end

  it 'registers an offense for def_delegators' do
    expect_offense(<<~RUBY)
      def_delegators :@user, :name, :email
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Do not use automatic delegation. Delete the forwarder and let the caller navigate.
    RUBY
  end

  it 'registers an offense for DelegateClass' do
    expect_offense(<<~RUBY)
      DelegateClass(User)
      ^^^^^^^^^^^^^^^^^^^ Do not use automatic delegation. Delete the forwarder and let the caller navigate.
    RUBY
  end

  it 'does not register an offense for a same-named call with a receiver' do
    expect_no_offenses(<<~RUBY)
      event.delegate(:approve)
    RUBY
  end

  it 'registers an offense for a method forwarding its own name to a collaborator' do
    expect_offense(<<~RUBY)
      def name
          ^^^^ Do not forward a collaborator's message. Delete the forwarder and let the caller navigate.
        commission.name
      end
    RUBY
  end

  it 'registers an offense for a method forwarding through a chain' do
    expect_offense(<<~RUBY)
      def starts_at
          ^^^^^^^^^ Do not forward a collaborator's message. Delete the forwarder and let the caller navigate.
        commission.plan.period.starts_at
      end
    RUBY
  end

  it 'registers an offense for a method forwarding to an instance variable' do
    expect_offense(<<~RUBY)
      def id
          ^^ Do not forward a collaborator's message. Delete the forwarder and let the caller navigate.
        @calendar_audit.id
      end
    RUBY
  end

  it 'registers an offense for a setter forwarding its own name' do
    expect_offense(<<~RUBY)
      def name=(value)
          ^^^^^ Do not forward a collaborator's message. Delete the forwarder and let the caller navigate.
        commission.name = value
      end
    RUBY
  end

  it 'does not register an offense for a method whose name differs from the forwarded message' do
    expect_no_offenses(<<~RUBY)
      def full_name
        user.name
      end
    RUBY
  end

  it 'does not register an offense for a method that does more than forward' do
    expect_no_offenses(<<~RUBY)
      def name
        return 'unknown' if commission.blank?

        commission.name
      end
    RUBY
  end

  it 'does not register an offense for a method delegating to super' do
    expect_no_offenses(<<~RUBY)
      def name
        super
      end
    RUBY
  end

  it 'does not register an offense for a receiverless call to the same name' do
    expect_no_offenses(<<~RUBY)
      def name
        read_attribute(:name)
      end
    RUBY
  end

  it 'does not register an offense for a class method forwarding its own name' do
    expect_no_offenses(<<~RUBY)
      def self.find
        repository.find
      end
    RUBY
  end
end
