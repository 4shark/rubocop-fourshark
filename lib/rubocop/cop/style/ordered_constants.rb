# frozen_string_literal: true

require 'rubocop'

module RuboCop
  module Cop
    module Style
      # Requires a run of consecutive constant assignments to be sorted
      # alphabetically by name. A lone constant is never flagged; a run is
      # broken by any non-constant statement. A constant whose value references
      # one declared above it in the run is not flagged, since Ruby cannot load
      # it any earlier. Flags without autocorrecting. Experimental: if it flags
      # more than it helps, drop it.
      class OrderedConstants < ::RuboCop::Cop::Base
        MSG = 'Sort constant assignments alphabetically (`%<name>s` should come before `%<previous>s`).'

        def on_begin(node)
          node.children.chunk { |child| constant_assignment?(child) }.each do |constants, run|
            flag_unsorted(run) if constants
          end
        end

        private

        def flag_unsorted(run)
          run.each_cons(2).with_index do |(previous, current), index|
            previous_name = constant_name(previous)
            current_name = constant_name(current)

            next if current_name >= previous_name
            next if references_earlier_constant?(current, run.first(index + 1))

            add_offense(current.loc.name, message: format(MSG, name: current_name, previous: previous_name))
          end
        end

        def references_earlier_constant?(node, earlier_constants)
          earlier_names = earlier_constants.map { |constant| constant_name(constant) }

          node.expression.each_node(:const).any? do |reference|
            reference.namespace.nil? && earlier_names.include?(reference.short_name.to_s)
          end
        end

        def constant_assignment?(node)
          node.is_a?(::RuboCop::AST::Node) && node.casgn_type?
        end

        def constant_name(node)
          node.name.to_s
        end
      end
    end
  end
end
