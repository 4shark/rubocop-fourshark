# frozen_string_literal: true

require 'rubocop'

module RuboCop
  module Cop
    module Style
      # Requires a run of consecutive constant assignments to be sorted
      # alphabetically by name. A lone constant is never flagged; a run is
      # broken by any non-constant statement. Flags without autocorrecting — a
      # constant may reference one declared above it, so a human decides the
      # order. Experimental: if it flags more than it helps, drop it.
      class OrderedConstants < ::RuboCop::Cop::Base
        MSG = 'Sort constant assignments alphabetically (`%<name>s` should come before `%<previous>s`).'

        def on_begin(node)
          node.children.chunk { |child| constant_assignment?(child) }.each do |constants, run|
            flag_unsorted(run) if constants
          end
        end

        private

        def flag_unsorted(run)
          run.each_cons(2) do |previous, current|
            previous_name = constant_name(previous)
            current_name = constant_name(current)

            next if current_name >= previous_name

            add_offense(current.loc.name, message: format(MSG, name: current_name, previous: previous_name))
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
