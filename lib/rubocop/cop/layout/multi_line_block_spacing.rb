# frozen_string_literal: true

require 'rubocop'

module RuboCop
  module Cop
    module Layout
      # Requires a blank line between two consecutive statements when either of
      # them spans multiple lines. Adjacent single-line statements need no blank
      # line. The boundary with the enclosing `def`/`do`/`end` is left to other
      # cops.
      #
      # Detection-only (no autocorrect) for now — the comment-handling and
      # autocorrect behaviour need validation against the real repos first.
      #
      # @example
      #   # bad
      #   foo(
      #     bar
      #   )
      #   baz
      #
      #   # good
      #   foo(
      #     bar
      #   )
      #
      #   baz
      #
      class MultiLineBlockSpacing < ::RuboCop::Cop::Base
        MSG = 'Add a blank line around multi-line statements.'

        def on_begin(node)
          node.children.each_cons(2) do |first, second|
            next unless first.is_a?(::RuboCop::AST::Node) && second.is_a?(::RuboCop::AST::Node)
            next unless first.multiline? || second.multiline?
            next if blank_line_between?(first, second)

            add_offense(second)
          end
        end

        private

        def blank_line_between?(first, second)
          return false if second.first_line - first.last_line < 2

          ((first.last_line + 1)...second.first_line).any? do |line|
            processed_source.lines[line - 1].strip.empty?
          end
        end
      end
    end
  end
end
