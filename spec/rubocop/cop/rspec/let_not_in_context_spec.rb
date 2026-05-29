# frozen_string_literal: true

RSpec.describe RuboCop::Cop::RSpec::LetNotInContext, :config do
  it 'registers an offense for let inside a context' do
    expect_offense(<<~RUBY)
      RSpec.describe Foo do
        context 'when x' do
          let(:user) { create(:user) }
          ^^^ Declare `let` at the top level, not inside a `context`.
        end
      end
    RUBY
  end

  it 'does not register for let at the top level' do
    expect_no_offenses(<<~RUBY)
      RSpec.describe Foo do
        let(:user) { create(:user) }
      end
    RUBY
  end
end
