# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Style::DisallowDelegate, :config do
  # Anonymous block forwarding — `def each(&)` — is Ruby 3.1, the version the
  # gemspec already requires. RuboCop's own default parser target is older.
  let(:ruby_version) { 3.1 }

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
        author.name
      end
    RUBY
  end

  it 'registers an offense for a method forwarding through a chain' do
    expect_offense(<<~RUBY)
      def starts_at
          ^^^^^^^^^ Do not forward a collaborator's message. Delete the forwarder and let the caller navigate.
        schedule.window.period.starts_at
      end
    RUBY
  end

  it 'registers an offense for a method forwarding to an instance variable' do
    expect_offense(<<~RUBY)
      def id
          ^^ Do not forward a collaborator's message. Delete the forwarder and let the caller navigate.
        @account.id
      end
    RUBY
  end

  it 'registers an offense for a setter forwarding its own name' do
    expect_offense(<<~RUBY)
      def name=(value)
          ^^^^^ Do not forward a collaborator's message. Delete the forwarder and let the caller navigate.
        author.name = value
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
        return 'unknown' if author.blank?

        author.name
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

  it 'does not register an offense for a method composing its attributes into its own class method' do
    expect_no_offenses(<<~RUBY)
      def lock_key
        self.class.lock_key(owner_id: owner_id)
      end
    RUBY
  end

  it 'does not register an offense for a method forwarding to its own class without arguments' do
    expect_no_offenses(<<~RUBY)
      def cache_ttl
        self.class.cache_ttl
      end
    RUBY
  end

  it 'registers an offense for a method forwarding to a collaborator class method' do
    expect_offense(<<~RUBY)
      def lock_key
          ^^^^^^^^ Do not forward a collaborator's message. Delete the forwarder and let the caller navigate.
        Registry.lock_key
      end
    RUBY
  end

  it 'registers an offense for a method forwarding to a collaborator own class' do
    expect_offense(<<~RUBY)
      def lock_key
          ^^^^^^^^ Do not forward a collaborator's message. Delete the forwarder and let the caller navigate.
        post.class.lock_key(owner_id: user.owner_id)
      end
    RUBY
  end

  it 'does not register an offense for a method composing own state reached through a call' do
    expect_no_offenses(<<~RUBY)
      def lock_key
        Registry.lock_key(owner_id: record.owner_id)
      end
    RUBY
  end

  it 'does not register an offense for each in a class including Enumerable' do
    expect_no_offenses(<<~RUBY)
      class SearchResult
        include Enumerable

        def each(&)
          results.each(&)
        end
      end
    RUBY
  end

  it 'does not register an offense for each in a class including Enumerable among other statements' do
    expect_no_offenses(<<~RUBY)
      class SearchResult
        include Comparable
        include ::Enumerable

        attr_reader :raw_response

        def each(&)
          results.each(&)
        end
      end
    RUBY
  end

  it 'registers an offense for each in a class that does not include Enumerable' do
    expect_offense(<<~RUBY)
      class SearchResult
        def each(&)
            ^^^^ Do not forward a collaborator's message. Delete the forwarder and let the caller navigate.
          results.each(&)
        end
      end
    RUBY
  end

  it 'registers an offense for a method other than each in a class including Enumerable' do
    expect_offense(<<~RUBY)
      class SearchResult
        include Enumerable

        def size
            ^^^^ Do not forward a collaborator's message. Delete the forwarder and let the caller navigate.
          results.size
        end
      end
    RUBY
  end

  it 'does not register an offense for a method composing its own attribute into the call' do
    expect_no_offenses(<<~RUBY)
      def output
        formatter.output(value)
      end
    RUBY
  end

  it 'does not register an offense for a method composing an instance variable into the call' do
    expect_no_offenses(<<~RUBY)
      def output
        formatter.output(@value)
      end
    RUBY
  end

  it 'does not register an offense for a method composing its own attribute into a keyword argument' do
    expect_no_offenses(<<~RUBY)
      def lock_key
        Registry.lock_key(owner_id: owner_id)
      end
    RUBY
  end

  it 'registers an offense for a setter forwarding its own parameter' do
    expect_offense(<<~RUBY)
      def output=(value)
          ^^^^^^^ Do not forward a collaborator's message. Delete the forwarder and let the caller navigate.
        formatter.output = value
      end
    RUBY
  end

  it 'does not register an offense for own state passed through a splat' do
    expect_no_offenses(<<~RUBY)
      def output
        formatter.output(*items)
      end
    RUBY
  end

  it 'does not register an offense for own state passed through a double splat' do
    expect_no_offenses(<<~RUBY)
      def options
        formatter.options(**settings)
      end
    RUBY
  end

  it 'does not register an offense for own state passed through an array' do
    expect_no_offenses(<<~RUBY)
      def values
        formatter.values([value])
      end
    RUBY
  end

  it 'does not register an offense for own state passed through a block' do
    expect_no_offenses(<<~RUBY)
      def each
        results.each(&@handler)
      end
    RUBY
  end

  it 'does not register an offense for own state reached through another call' do
    expect_no_offenses(<<~RUBY)
      def label
        formatter.label(value.to_s)
      end
    RUBY
  end

  it 'registers an offense for a chained receiver carrying an own state argument' do
    expect_offense(<<~RUBY)
      def starts_at
          ^^^^^^^^^ Do not forward a collaborator's message. Delete the forwarder and let the caller navigate.
        schedule.window.period.starts_at(calendar)
      end
    RUBY
  end

  it 'does not register an offense for an instance variable receiver carrying an own state argument' do
    expect_no_offenses(<<~RUBY)
      def id
        @account.id(scope)
      end
    RUBY
  end

  it 'does not register an offense for a direct collaborator carrying an own state argument' do
    expect_no_offenses(<<~RUBY)
      def name
        author.name(locale)
      end
    RUBY
  end

  it 'does not register an offense for each in a class prepending Enumerable' do
    expect_no_offenses(<<~RUBY)
      class SearchResult
        prepend Enumerable

        def each(&)
          results.each(&)
        end
      end
    RUBY
  end

  it 'does not register an offense for each in a module including Enumerable' do
    expect_no_offenses(<<~RUBY)
      module Collection
        include Enumerable

        def each(&)
          results.each(&)
        end
      end
    RUBY
  end

  it 'registers an offense for each in a singleton class of a class including Enumerable' do
    expect_offense(<<~RUBY)
      class SearchResult
        include Enumerable

        class << self
          def each(&)
              ^^^^ Do not forward a collaborator's message. Delete the forwarder and let the caller navigate.
            results.each(&)
          end
        end
      end
    RUBY
  end

  it 'registers an offense for each outside any class' do
    expect_offense(<<~RUBY)
      def each(&)
          ^^^^ Do not forward a collaborator's message. Delete the forwarder and let the caller navigate.
        results.each(&)
      end
    RUBY
  end
end
