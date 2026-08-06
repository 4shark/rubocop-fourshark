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
      class Order < ApplicationRecord
        has_many :line_items, inverse_of: :order
        has_many :shipments, inverse_of: :order

        has_many :carriers, through: :shipments
        has_many :products, through: :line_items
      end
    RUBY
  end

  it 'registers an offense for unsorted :through associations within their own group' do
    expect_offense(<<~RUBY)
      class Order < ApplicationRecord
        has_many :shipments, inverse_of: :order

        has_many :products, through: :line_items
        has_many :carriers, through: :shipments
        ^^^^^^^^ Sort `has_many` declarations alphabetically (`carriers` should come before `products`).
      end
    RUBY
  end
end
