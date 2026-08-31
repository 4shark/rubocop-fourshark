# frozen_string_literal: true

require 'rubocop'

module RuboCop
  module Cop
    module RSpec
      # Forbids overriding a `let`/`let!` that is already defined in an outer
      # example group. Shadowing an ancestor's `let` makes it ambiguous which
      # value applies in a given example.
      #
      # A `let` that is specific to a single scenario is allowed, even when a
      # sibling context defines a `let` of the same name — siblings are separate
      # scopes and do not override each other. Only an inner `let` that shadows
      # an `let` from an ancestor example group is flagged.
      #
      # @example
      #   # bad — inner let shadows the outer one
      #   let(:user) { create(:user) }
      #
      #   context 'when admin' do
      #     let(:user) { create(:user, :admin) }
      #   end
      #
      #   # good — scenario-specific let, no ancestor defines it
      #   context 'when admin' do
      #     let(:user) { create(:user, :admin) }
      #   end
      #
      #   context 'when regular' do
      #     let(:user) { create(:user) }
      #   end
      #
      class OverwrittenLet < ::RuboCop::Cop::Base
        EXAMPLE_GROUP_METHODS = %i[describe context].freeze
        LET_METHODS = %i[let let!].freeze
        MSG = 'Do not override the outer `let` `%<name>s`; use a distinct name or set the value in `before`.'

        def on_send(node)
          return unless LET_METHODS.include?(node.method_name) && node.receiver.nil?

          name = let_name(node)

          return unless name

          immediate_group = node.each_ancestor(:block).find { |block| example_group?(block) }

          return unless immediate_group
          return unless outer_groups(immediate_group).any? { |group| defines_let?(group, name) }

          add_offense(node.loc.selector, message: format(MSG, name: name))
        end

        private

        def outer_groups(group)
          group.each_ancestor(:block).select { |block| example_group?(block) }
        end

        def example_group?(block)
          send = block.send_node
          EXAMPLE_GROUP_METHODS.include?(send.method_name)
        end

        def defines_let?(group, name)
          body = group.body

          return false unless body

          statements = if body.begin_type?
                         body.children
                       else
                         [body]
                       end

          statements.any? { |statement| let_named?(statement, name) }
        end

        def let_named?(statement, name)
          return false unless statement.is_a?(::RuboCop::AST::Node)

          send = if statement.respond_to?(:send_node)
                   statement.send_node
                 else
                   statement
                 end

          return false unless send.send_type?
          return false unless LET_METHODS.include?(send.method_name) && send.receiver.nil?

          first = send.first_argument
          first && first.sym_type? && first.value == name
        end

        def let_name(node)
          first = node.first_argument

          return first.value if first && first.sym_type?

          nil
        end
      end
    end
  end
end
