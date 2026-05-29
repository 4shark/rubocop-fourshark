# frozen_string_literal: true

RSpec.describe RuboCop::Cop::RSpec::ConditionalInLet, :config do
  it 'registers an offense for an if inside a let' do
    expect_offense(<<~RUBY)
      let(:user) do
        if admin?
        ^^ Do not put conditional logic in a `let` — use separate contexts.
          create(:user, :admin)
        else
          create(:user)
        end
      end
    RUBY
  end

  it 'does not register for a ternary' do
    expect_no_offenses(<<~RUBY)
      let(:role) { admin? ? :admin : :member }
    RUBY
  end
end
