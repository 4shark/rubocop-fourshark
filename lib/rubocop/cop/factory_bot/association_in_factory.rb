# frozen_string_literal: true

require 'rubocop'

module RuboCop
  module Cop
    module FactoryBot
      # Forbids declaring associations inside a `factory`/`trait` block. An
      # association is a bare attribute call with no value (e.g. `customer`),
      # which triggers cascading object creation and callbacks. Set the
      # association manually in the spec instead.
      #
      # @example
      #   # bad
      #   factory :payment do
      #     amount { 100.0 }
      #     customer
      #   end
      #
      #   # good
      #   factory :payment do
      #     amount { 100.0 }
      #   end
      #
      class AssociationInFactory < ::RuboCop::Cop::Base
        MSG = 'Do not declare associations in factories — set them manually in the spec.'
        CONTAINER_METHODS = %i[factory trait].freeze
        # FactoryBot DSL methods that are bare calls but are NOT associations.
        DSL_KEYWORDS = %i[skip_create initialize_with].freeze

        def on_block(node)
          return unless container_block?(node)

          body = node.body

          return unless body

          statements = if body.begin_type?
                         body.children
                       else
                         [body]
                       end

          statements.each do |statement|
            add_offense(statement.loc.selector) if association_call?(statement)
          end
        end

        alias on_numblock on_block
        alias on_itblock on_block

        private

        def container_block?(node)
          send = node.send_node
          CONTAINER_METHODS.include?(send.method_name) && send.receiver.nil?
        end

        # A bare attribute call (no receiver, no arguments, no block) inside a
        # factory body is an implicit association.
        def association_call?(node)
          return false unless node.is_a?(::RuboCop::AST::Node) && node.send_type?
          return false unless node.receiver.nil? && node.arguments.empty?
          return false if DSL_KEYWORDS.include?(node.method_name)

          true
        end
      end
    end
  end
end
