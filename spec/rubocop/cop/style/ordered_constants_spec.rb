# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Style::OrderedConstants, :config do
  it 'registers an offense for a run of constants out of alphabetical order' do
    expect_offense(<<~RUBY)
      class Cop
        LET_METHODS = %i[let let!].freeze
        EXAMPLE_GROUP_METHODS = %i[describe context].freeze
        ^^^^^^^^^^^^^^^^^^^^^ Sort constant assignments alphabetically (`EXAMPLE_GROUP_METHODS` should come before `LET_METHODS`).
      end
    RUBY
  end

  it 'flags the message constant when it is out of alphabetical position' do
    expect_offense(<<~RUBY)
      class Cop
        MSG = 'boom'
        LET_METHODS = %i[let let!].freeze
        ^^^^^^^^^^^ Sort constant assignments alphabetically (`LET_METHODS` should come before `MSG`).
      end
    RUBY
  end

  it 'does not register when the run is sorted' do
    expect_no_offenses(<<~RUBY)
      class Cop
        EXAMPLE_GROUP_METHODS = %i[describe context].freeze
        LET_METHODS = %i[let let!].freeze
        MSG = 'boom'
      end
    RUBY
  end

  it 'does not register for a single constant' do
    expect_no_offenses(<<~RUBY)
      class Cop
        MSG = 'boom'

        def call; end
      end
    RUBY
  end

  it 'does not compare constants separated by a method definition' do
    expect_no_offenses(<<~RUBY)
      class Cop
        ZED = 1

        def call; end

        ABE = 2
      end
    RUBY
  end

  it 'reports each locally out-of-order pair in a run' do
    expect_offense(<<~RUBY)
      class Cop
        ZEBRA = 1
        MANGO = 2
        ^^^^^ Sort constant assignments alphabetically (`MANGO` should come before `ZEBRA`).
        APPLE = 3
        ^^^^^ Sort constant assignments alphabetically (`APPLE` should come before `MANGO`).
      end
    RUBY
  end

  it 'treats constants separated only by a comment as one run' do
    expect_offense(<<~RUBY)
      class Cop
        MANGO = 1
        # a note
        APPLE = 2
        ^^^^^ Sort constant assignments alphabetically (`APPLE` should come before `MANGO`).
      end
    RUBY
  end
end
