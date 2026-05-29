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
        rescue StandardError => e
          source_name =
            if processed_source && processed_source.buffer
              processed_source.file_path
            else
              'unknown'
            end

          warn "Rails/BidirectionalAssociation failed on #{source_name}: #{e.message}"
        end

        private

        def associations
          processed_source.ast.each_descendant(:send).filter_map do |node|
            next unless %i[belongs_to has_many has_one].include?(node.method_name)

            # Skip polymorphic associations and `as:` options
            next if polymorphic_or_as?(node)

            model_name = class_name_from_ast

            assoc_name =
              begin
                node.first_argument.value if node.first_argument
              rescue StandardError
                nil
              end

            inverse_name = extract_inverse_of(node)
            target_class = extract_class_name(node, assoc_name)

            [model_name, assoc_name, inverse_name, target_class]
          end
        end

        def extract_inverse_of(node)
          kwargs = node.last_argument
          return nil unless kwargs && kwargs.hash_type?

          pair =
            begin
              kwargs.pairs.find { |p| p.key.value == :inverse_of }
            rescue StandardError
              nil
            end

          pair.value.value if pair && pair.value
        end

        def extract_class_name(node, assoc_name)
          kwargs = node.last_argument
          return assoc_name.to_s.camelize unless kwargs && kwargs.hash_type?

          class_name_pair =
            begin
              kwargs.pairs.find { |p| p.key.value == :class_name }
            rescue StandardError
              nil
            end

          if class_name_pair
            class_name_pair.value.value
          else
            assoc_name.to_s.camelize
          end
        end

        def polymorphic_or_as?(node)
          kwargs = node.last_argument
          return false unless kwargs && kwargs.hash_type?

          kwargs.pairs.any? do |pair|
            key = pair.key.value
            %i[polymorphic as].include?(key)
          end
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
