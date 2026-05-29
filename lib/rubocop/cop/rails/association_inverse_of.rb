# frozen_string_literal: true

require 'rubocop'

module RuboCop
  module Cop
    module Rails
      # Ensures that every ActiveRecord association
      # (belongs_to, has_many, has_one) has an `inverse_of` option.
      #
      # @example
      #   # bad
      #   belongs_to :user
      #
      #   # good
      #   belongs_to :user, inverse_of: :posts
      #
      class AssociationInverseOf < ::RuboCop::Cop::Base
        MSG = 'All associations must declare `inverse_of`.'

        def self.default_configuration
          super.merge(
            'Include' => ['app/models/**/*.rb'],
            'Exclude' => ['app/serializers/**/*.rb']
          )
        end

        def on_send(node)
          return unless in_model_file?(processed_source.file_path)
          return unless association?(node)
          return if polymorphic_or_through?(node)

          kwargs = node.last_argument

          missing_inverse_of =
            !kwargs || !kwargs.hash_type? || kwargs.keys.none? { |k| k.value == :inverse_of }

          add_offense(node.loc.selector) if missing_inverse_of
        rescue StandardError => e
          source_name =
            if processed_source && processed_source.buffer
              processed_source.file_path
            else
              'unknown'
            end

          warn "Rails/AssociationInverseOf failed on #{source_name}: #{e.message}"
        end

        private

        def association?(node)
          %i[belongs_to has_many has_one].include?(node.method_name)
        end

        def in_model_file?(path)
          return false if path.nil?

          path.start_with?(File.join(Dir.pwd, 'app/models'))
        end

        # Detects if the association has `polymorphic: true` or `through: ...`
        def polymorphic_or_through?(node)
          # Look for any hash arguments and check their keys
          node.arguments.any? do |arg|
            next false unless arg.hash_type?

            arg.keys.any? { |k| %i[polymorphic through].include?(k.value) }
          end
        end
      end
    end
  end
end
