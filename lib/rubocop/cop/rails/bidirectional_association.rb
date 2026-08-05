# frozen_string_literal: true

require 'rubocop'

module RuboCop
  module Cop
    module Rails
      # Ensures that all ActiveRecord associations are declared on both sides.
      #
      # Example:
      #   # bad
      #   class Post < ApplicationRecord
      #     belongs_to :user
      #   end
      #
      #   class User < ApplicationRecord
      #   end
      #
      #   # good
      #   class Post < ApplicationRecord
      #     belongs_to :user, inverse_of: :posts
      #   end
      #
      #   class User < ApplicationRecord
      #     has_many :posts, inverse_of: :user
      #   end
      #
      class BidirectionalAssociation < ::RuboCop::Cop::Base
        MSG = 'Associations must be declared on both sides of the relationship.'

        def self.default_configuration
          super.merge(
            'Include' => ['app/models/**/*.rb'],
            'Exclude' => ['app/serializers/**/*.rb']
          )
        end

        def on_new_investigation
          return unless in_model_file?(processed_source.file_path)
          return unless processed_source.ast

          associations.each do |model_name, _assoc_name, inverse_name, target_class|
            next if model_name.nil? || target_class.nil?

            opposite_model_path = File.join(Dir.pwd, "app/models/#{camel_to_snake(target_class)}.rb")
            next unless File.exist?(opposite_model_path)

            opposite_content = File.read(opposite_model_path)

            expected_inverse =
              if inverse_name
                inverse_name.to_s
              else
                camel_to_snake(model_name).split('/').last.pluralize
              end

            unless /(belongs_to|has_many|has_one)\s+:#{expected_inverse}/.match?(opposite_content)
              add_global_offense("#{target_class} is missing opposite association for #{model_name}")
            end
          end
        rescue StandardError => exception
          source_name =
            if processed_source && processed_source.buffer
              processed_source.file_path
            else
              'unknown'
            end

          warn "Rails/BidirectionalAssociation failed on #{source_name}: #{exception.message}"
        end

        private

        def associations
          processed_source.ast.each_descendant(:send).filter_map do |node|
            next unless %i[belongs_to has_many has_one].include?(node.method_name)

            # Skip polymorphic associations, `as:` options, and explicit `inverse_of: nil/false`
            next if polymorphic_or_as?(node)
            next if inverse_disabled?(node)

            model_name = class_name_from_ast
            assoc_name = literal_value(node.first_argument)
            inverse_name = extract_inverse_of(node)
            target_class = extract_class_name(node, assoc_name)

            [model_name, assoc_name, inverse_name, target_class]
          end
        end

        def extract_inverse_of(node)
          literal_value(option_value(node, :inverse_of))
        end

        def extract_class_name(node, assoc_name)
          literal_value(option_value(node, :class_name)) || assoc_name.to_s.camelize
        end

        def inverse_disabled?(node)
          value = option_value(node, :inverse_of)
          value.falsey_literal? if value
        end

        def polymorphic_or_as?(node)
          %i[polymorphic as].any? { |key| option_pair(node, key) }
        end

        # The keyword options hash is the last argument; pairs whose key is not a
        # plain symbol (string keys, double-splats) are skipped rather than read.
        def option_pair(node, key)
          kwargs = node.last_argument
          return nil unless kwargs.respond_to?(:hash_type?) && kwargs.hash_type?

          kwargs.pairs.find { |pair| pair.key.sym_type? && pair.key.value == key }
        end

        def option_value(node, key)
          pair = option_pair(node, key)
          pair.value if pair
        end

        # A node's literal value, only when it actually carries one — guards
        # against non-literal options like `inverse_of: nil` or `class_name: Foo`.
        def literal_value(node)
          node.value if node.respond_to?(:value)
        end

        def class_name_from_ast
          class_node = processed_source.ast.each_descendant(:class).first
          return nil unless class_node

          const_node = class_node.children.first
          const_node.const_name if const_node
        end

        def in_model_file?(path)
          return false if path.nil?

          path.start_with?(File.join(Dir.pwd, 'app/models'))
        end

        # Replace ActiveSupport's underscore with plain Ruby equivalent
        #
        # Example:
        #   "UserAccount" → "user_account"
        #   "PlanStatementAudit::Row" → "plan_statement_audit/row"
        def camel_to_snake(name)
          return '' if name.nil?

          name.gsub('::', '/')
            .gsub(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
            .gsub(/([a-z\d])([A-Z])/, '\1_\2')
            .downcase
        end
      end
    end
  end
end
