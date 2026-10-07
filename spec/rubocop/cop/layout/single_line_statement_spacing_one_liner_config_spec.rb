# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Layout::SingleLineStatementSpacing, :config do
  let(:other_cops) do
    {
      'RSpec/EmptyLineAfterExample' => { 'AllowConsecutiveOneLiners' => false },
      'RSpec/EmptyLineAfterHook' => { 'AllowConsecutiveOneLiners' => false }
    }
  end

  it 'keeps the blank line between two one-line hooks' do
    expect_no_offenses(<<~RUBY)
      before { user.save }

      before { admin.save }
    RUBY
  end

  it 'keeps the blank line between two one-line examples' do
    expect_no_offenses(<<~RUBY)
      it { is_expected.to be_valid }

      it { is_expected.to be_persisted }
    RUBY
  end

  it 'removes the blank line between two lets' do
    expect_offense(<<~RUBY)
      let(:user) { build(:user) }

      let(:admin) { build(:admin) }
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Remove the blank line between consecutive single-line statements.
    RUBY

    expect_correction(<<~RUBY)
      let(:user) { build(:user) }
      let(:admin) { build(:admin) }
    RUBY
  end
end
