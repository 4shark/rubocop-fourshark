# frozen_string_literal: true

RSpec.describe RuboCop::Cop::FactoryBot::AssociationInFactory, :config do
  it 'registers an offense for a bare association in a factory' do
    expect_offense(<<~RUBY)
      factory :payment do
        amount { 100.0 }
        customer
        ^^^^^^^^ Do not declare associations in factories — set them manually in the spec.
      end
    RUBY
  end

  it 'does not register for attributes with values' do
    expect_no_offenses(<<~RUBY)
      factory :payment do
        amount { 100.0 }
        status { :pending }
      end
    RUBY
  end
end
