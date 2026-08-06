# frozen_string_literal: true

RSpec.describe RuboCop::Cop::RSpec::InverseOfMatcher, :config do
  context 'when the model is a root (< ApplicationRecord)' do
    before do
      allow_any_instance_of(described_class)
        .to receive(:model_source).and_return("class Device < ApplicationRecord\nend")
    end

    it 'registers an offense for an association without .inverse_of' do
      expect_offense(<<~RUBY, 'spec/models/device_spec.rb')
        RSpec.describe Device do
          it { is_expected.to belong_to(:configuration) }
                              ^^^^^^^^^ Root models must include `.inverse_of` in association specs.
        end
      RUBY
    end

    it 'accepts an association with .inverse_of' do
      expect_no_offenses(<<~RUBY, 'spec/models/device_spec.rb')
        RSpec.describe Device do
          it { is_expected.to belong_to(:configuration).inverse_of(:devices) }
        end
      RUBY
    end
  end

  context 'when the model is an STI subclass' do
    before do
      allow_any_instance_of(described_class).to receive(:model_source) do |_cop, name|
        { 'AdminUser' => "class AdminUser < User\nend", 'User' => "class User < ApplicationRecord\nend" }[name]
      end
    end

    it 'registers an offense for an association with .inverse_of' do
      expect_offense(<<~RUBY, 'spec/models/admin_user_spec.rb')
        RSpec.describe AdminUser do
          it { is_expected.to belong_to(:company).inverse_of(:admin_users) }
                              ^^^^^^^^^ Subclasses must NOT include `.inverse_of` in specs (it belongs to the parent).
        end
      RUBY
    end
  end

  context 'when the model declares the association as polymorphic' do
    before do
      model = <<~MODEL
        class Attachment < ApplicationRecord
          belongs_to :attachable, polymorphic: true, optional: true
        end
      MODEL
      allow_any_instance_of(described_class).to receive(:model_source).and_return(model)
    end

    it 'does not require .inverse_of for the polymorphic association' do
      expect_no_offenses(<<~RUBY, 'spec/models/attachment_spec.rb')
        RSpec.describe Attachment do
          it { is_expected.to belong_to(:attachable) }
        end
      RUBY
    end
  end

  context 'when the model is a nested class that is itself a root' do
    before do
      invoice_row = <<~MODEL
        class Invoice < Document
          class Row < ApplicationRecord
            belongs_to :invoice, inverse_of: :rows, optional: true
          end
        end
      MODEL

      document = "class Document < ApplicationRecord\nend"

      allow_any_instance_of(described_class).to receive(:model_source) do |_cop, name|
        { 'Invoice::Row' => invoice_row, 'Document' => document }[name]
      end
    end

    it 'classifies the nested class by its own superclass, not the wrapper' do
      expect_no_offenses(<<~RUBY, 'spec/models/invoice/row_spec.rb')
        RSpec.describe Invoice::Row do
          it { is_expected.to belong_to(:invoice).inverse_of(:rows) }
        end
      RUBY
    end

    it 'registers an offense when the nested root association lacks .inverse_of' do
      expect_offense(<<~RUBY, 'spec/models/invoice/row_spec.rb')
        RSpec.describe Invoice::Row do
          it { is_expected.to belong_to(:invoice) }
                              ^^^^^^^^^ Root models must include `.inverse_of` in association specs.
        end
      RUBY
    end
  end

  it 'does not register (and does not crash) when the model file is missing' do
    allow_any_instance_of(described_class).to receive(:model_source).and_return(nil)

    expect_no_offenses(<<~RUBY, 'spec/models/ghost_spec.rb')
      RSpec.describe Ghost do
        it { is_expected.to belong_to(:thing) }
      end
    RUBY
  end
end
