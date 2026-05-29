# frozen_string_literal: true

RSpec.describe RuboCop::Cop::RSpec::OverwrittenLet, :config do
  it 'registers an offense when an inner let shadows an outer let' do
    expect_offense(<<~RUBY)
      RSpec.describe Foo do
        let(:user) { create(:user) }

        context 'when admin' do
          let(:user) { create(:user, :admin) }
          ^^^ Do not override the outer `let` `user`; use a distinct name or set the value in `before`.
        end
      end
    RUBY
  end

  it 'does not register for a scenario-specific let with no ancestor of the same name' do
    expect_no_offenses(<<~RUBY)
      RSpec.describe Foo do
        context 'when admin' do
          let(:user) { create(:user, :admin) }
        end
      end
    RUBY
  end

  it 'does not register for the same let name across sibling contexts' do
    expect_no_offenses(<<~RUBY)
      RSpec.describe Foo do
        context 'with valid configuration' do
          let(:expected_attributes) { { name: 'a' } }
        end

        context 'with valid configuration defined for the device' do
          let(:expected_attributes) { { name: 'a' } }
        end
      end
    RUBY
  end

  it 'does not register for a top-level let' do
    expect_no_offenses(<<~RUBY)
      RSpec.describe Foo do
        let(:user) { create(:user) }
      end
    RUBY
  end
end
