# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Rails::OrderedMacros, :config do
  it 'registers an offense for unsorted validations' do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        validates :name
        validates :email
        ^^^^^^^^^ Sort `validates` declarations alphabetically (`email` should come before `name`).
      end
    RUBY
  end

  it 'registers an offense for unsorted scopes' do
    expect_offense(<<~RUBY)
      class User < ApplicationRecord
        scope :recent, -> { order(created_at: :desc) }
        scope :active, -> { where(active: true) }
        ^^^^^ Sort `scope` declarations alphabetically (`active` should come before `recent`).
      end
    RUBY
  end

  it 'registers an offense for unsorted belongs_to within its own group' do
    expect_offense(<<~RUBY)
      class Order < ApplicationRecord
        belongs_to :store, optional: true
        belongs_to :customer, optional: true
        ^^^^^^^^^^ Sort `belongs_to` declarations alphabetically (`customer` should come before `store`).
      end
    RUBY
  end

  it 'does not register when each macro group is sorted' do
    expect_no_offenses(<<~RUBY)
      class User < ApplicationRecord
        belongs_to :company, optional: true

        validates :email
        validates :name

        scope :active, -> { where(active: true) }
        scope :recent, -> { order(created_at: :desc) }
      end
    RUBY
  end

  it 'does not flag a :through association that follows the regular ones' do
    expect_no_offenses(<<~RUBY)
      class Indicator < ApplicationRecord
        has_many :eligible_indicators, inverse_of: :indicator
        has_many :enrollments, inverse_of: :indicator

        has_many :documents, through: :enrollments
        has_many :eligibility_periods, through: :eligible_indicators
      end
    RUBY
  end

  it 'registers an offense for unsorted :through associations within their own group' do
    expect_offense(<<~RUBY)
      class Indicator < ApplicationRecord
        has_many :enrollments, inverse_of: :indicator

        has_many :eligibility_periods, through: :eligible_indicators
        has_many :documents, through: :enrollments
        ^^^^^^^^ Sort `has_many` declarations alphabetically (`documents` should come before `eligibility_periods`).
      end
    RUBY
  end
end
