# frozen_string_literal: true

RSpec.describe RuboCop::Cop::RSpec::NoFactoryBotInBefore, :config do
  it 'registers an offense for create in a before block' do
    expect_offense(<<~RUBY)
      before do
        @user = create(:user)
                ^^^^^^ Do not create objects in `before` — use `let` for object creation.
      end
    RUBY
  end

  it 'does not register for an action in before' do
    expect_no_offenses(<<~RUBY)
      before { status.enable }
    RUBY
  end
end
