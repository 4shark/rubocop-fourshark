# frozen_string_literal: true

require 'rubocop'

module RuboCop
  module Cop
    module RSpec
      # Ensures that RSpec association specs handle `.inverse_of` correctly
      # depending on whether the model is a root (directly `< ApplicationRecord`)
      # or an STI subclass.
      #
      # Rules:
      # - Root models (direct superclass = `ApplicationRecord`) must include `.inverse_of`.
      # - STI subclasses (superclass is another model) must NOT include `.inverse_of` (it belongs to the parent).
      # - Associations the model declares as polymorphic are ignored (they have no single inverse).
      # - Classes whose model file is missing or whose superclass is not a model are ignored.
      #
      # The root/subclass decision is made **statically** — by reading the model
      # file and parsing its `class X < Y` declaration. The cop never loads the
      # model class (a linter runs without the Rails app booted).
      #
      class InverseOfMatcher < ::RuboCop::Cop::Base
        MSG_MISSING_INVERSE   = 'Root models must include `.inverse_of` in association specs.'
        MSG_FORBIDDEN_INVERSE = 'Subclasses must NOT include `.inverse_of` in specs (it belongs to the parent).'

        def self.default_configuration
          super.merge(
            'Include' => ['spec/models/**/*_spec.rb']
          )
        end

        def on_send(node)
          return unless node.method?(:belong_to)

          model_name = model_class_from_spec

          return unless model_name

          association_name = association_name_from(node)

          return if association_name && polymorphic_in_model?(model_name, association_name)

          classification = classify_model(model_name)

          return if classification == :non_ar

          if classification == :root
            add_offense(node.loc.selector, message: MSG_MISSING_INVERSE) unless chain_has_inverse_of?(node)
          elsif classification == :subclass
            add_offense(node.loc.selector, message: MSG_FORBIDDEN_INVERSE) if chain_has_inverse_of?(node)
          end
        rescue StandardError => exception
          source_name = if processed_source && processed_source.buffer
                          processed_source.file_path
                        else
                          'unknown'
                        end

          warn "RSpec/InverseOfMatcher failed on #{source_name}: #{exception.message}"
        end

        private

        # Check if .inverse_of exists in the send chain
        def chain_has_inverse_of?(node)
          node.each_ancestor(:send).any? { |ancestor| ancestor.method?(:inverse_of) }
        end

        # The association name passed to the matcher, e.g. belong_to(:user) -> :user
        def association_name_from(node)
          argument = node.first_argument

          return nil unless argument && argument.sym_type?

          argument.value
        end

        # Whether the model declares this association as polymorphic. Polymorphic
        # associations have no single inverse, so `.inverse_of` does not apply —
        # and the declaration lives in the model, not in the spec matcher chain.
        def polymorphic_in_model?(model_name, association_name)
          content = model_source(model_name)

          return false unless content

          content.match?(/belongs_to\s+:#{Regexp.escape(association_name.to_s)}\b[^\n]*polymorphic:\s*true/)
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

        # Classify the model as :root, :subclass, or :non_ar by reading the
        # model file statically (no class loading).
        def classify_model(model_name)
          content = model_source(model_name)

          return :non_ar unless content

          superclass = superclass_of(content, model_name)

          return :non_ar unless superclass
          return :root if superclass == 'ApplicationRecord'
          return :subclass if model_source(superclass)

          :non_ar
        rescue StandardError
          :non_ar
        end

        def model_source(model_name)
          path = File.join(Dir.pwd, 'app/models', "#{camel_to_snake(model_name)}.rb")

          return File.read(path) if File.exist?(path)

          nil
        end

        # The declared superclass of the specific class named by the spec — not the
        # first `class` line in the file. A nested `class Row < ApplicationRecord`
        # inside `class Wrapper < Parent` must resolve to its own superclass.
        def superclass_of(content, model_name)
          class_name = model_name.split('::').last
          match = content.match(/^\s*class\s+(?:[\w:]*::)?#{Regexp.escape(class_name)}\s*<\s*([\w:]+)/)
          match && match[1]
        end

        # "UserAccount" → "user_account"; "Order::LineItem" → "order/line_item"
        def camel_to_snake(name)
          name.gsub('::', '/')
            .gsub(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
            .gsub(/([a-z\d])([A-Z])/, '\1_\2')
            .downcase
        end
      end
    end
  end
end
