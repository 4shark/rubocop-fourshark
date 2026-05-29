# frozen_string_literal: true

require 'rubocop'

module RuboCop
  module Cop
    module RSpec
      # Ensures that RSpec association specs handle `.inverse_of`
      # correctly depending on whether the model is a root (directly < ApplicationRecord)
      # or a subclass (STI).
      #
      # Rules:
      # - Root models (direct superclass = ApplicationRecord) must include `.inverse_of`.
      # - Subclasses (STI, superclass != ApplicationRecord but still inherit indirectly) must NOT include `.inverse_of`.
      # - Associations marked as polymorphic or through are ignored.
      # - Non-ActiveRecord classes are ignored.
      #
      class AssociationInverseOf < ::RuboCop::Cop::Base
        MSG_MISSING_INVERSE   = 'Root models must include `.inverse_of` in association specs.'
        MSG_FORBIDDEN_INVERSE = 'Subclasses must NOT include `.inverse_of` in specs (it belongs to the parent).'

        def self.default_configuration
          super.merge(
            'Include' => ['spec/models/**/*_spec.rb']
          )
        end

        def on_send(node)
          return unless node.method?(:belong_to)

          # Skip polymorphic or through associations
          return if chain_has_option?(node, :polymorphic)
          return if chain_has_option?(node, :through)

          model_name = model_class_from_spec
          return unless model_name

          classification = classify_model(model_name)
          return if classification == :non_ar # ignore non-ActiveRecord classes

          if classification == :root
            add_offense(node.loc.selector, message: MSG_MISSING_INVERSE) unless chain_has_inverse_of?(node)
          elsif classification == :subclass
            add_offense(node.loc.selector, message: MSG_FORBIDDEN_INVERSE) if chain_has_inverse_of?(node)
          end
        rescue StandardError => e
          source_name =
            if processed_source && processed_source.buffer
              processed_source.file_path
            else
              'unknown'
            end

          warn "RSpec/AssociationInverseOf failed on #{source_name}: #{e.message}"
        end

        private

        # Check if .inverse_of exists in the send chain
        def chain_has_inverse_of?(node)
          node.each_ancestor(:send).any? { |ancestor| ancestor.method?(:inverse_of) }
        end

        # Check if association has a given option (e.g., :polymorphic, :through)
        def chain_has_option?(node, option_name)
          node.each_ancestor(:send).any? do |ancestor|
            ancestor.arguments.any? do |arg|
              arg.hash_type? && arg.keys.any? { |k| k.value == option_name }
            end
          end
        end

        # Convert spec file path into model class name
        def model_class_from_spec
          path = processed_source.file_path if processed_source && processed_source.buffer
          return nil unless path

          match = path.match(%r{spec/models/(.+)_spec\.rb})
          return nil unless match

          relative = match[1]
          return nil if relative.empty?

          relative.split('/').map { |part| part.split('_').map(&:capitalize).join }.join('::')
        end

        # Classify the model: :root, :subclass, or :non_ar
        def classify_model(model_name)
          require_dependency File.join('app/models', "#{model_name.underscore}.rb")
          klass = model_name.safe_constantize
          return :non_ar unless klass.is_a?(Class)

          if klass < ApplicationRecord
            return :root if klass.superclass == ApplicationRecord

            return :subclass
          end

          :non_ar
        rescue StandardError
          :non_ar
        end
      end
    end
  end
end
