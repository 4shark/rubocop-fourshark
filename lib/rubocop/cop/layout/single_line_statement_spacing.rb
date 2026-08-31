# frozen_string_literal: true

require 'rubocop'

module RuboCop
  module Cop
    module Layout
      # Forbids a blank line between two consecutive single-line statements —
      # they are one run, so the blank reveals nothing. A blank that separates
      # code from an adjacent comment is kept, as is one owned by another cop
      # (a guard clause, a flow-control statement, an access modifier) or one
      # beside a multi-line or heredoc neighbour. Autocorrects by removing it.
      class SingleLineStatementSpacing < ::RuboCop::Cop::Base
        extend ::RuboCop::Cop::AutoCorrector
        ACCESS_MODIFIERS = %i[private protected public module_function].freeze
        FLOW_CONTROL_METHODS = %i[raise fail throw].freeze
        FLOW_CONTROL_TYPES = %i[return next break redo retry].freeze
        MSG = 'Remove the blank line between consecutive single-line statements.'

        def on_begin(node)
          node.children.each_cons(2) do |first, second|
            next unless first.is_a?(::RuboCop::AST::Node) && second.is_a?(::RuboCop::AST::Node)
            next if structural?(first) || structural?(second)

            blanks = removable_blank_lines(first, second)

            next if blanks.empty?

            add_offense(second) do |corrector|
              blanks.each { |line| corrector.remove(line_range_with_newline(line)) }
            end
          end
        end

        private

        # A statement whose surrounding blank another cop owns, or which reads as
        # a block. Its blank is preserved: this cop only glues ordinary runs.
        def structural?(node)
          multiline_or_heredoc?(node) || flow_control?(node) || guard_clause?(node) || access_modifier?(node)
        end

        def multiline_or_heredoc?(node)
          node.multiline? || node.each_node(:any_str).any?(&:heredoc?)
        end

        def flow_control?(node)
          return true if FLOW_CONTROL_TYPES.include?(node.type)

          node.send_type? && node.receiver.nil? && FLOW_CONTROL_METHODS.include?(node.method_name)
        end

        def guard_clause?(node)
          return false unless node.if_type?

          branch = node.if_branch

          return false if branch.nil?

          branch.guard_clause?
        end

        def access_modifier?(node)
          node.send_type? && node.receiver.nil? && ACCESS_MODIFIERS.include?(node.method_name)
        end

        # A blank whose nearest non-blank line on each side is the same kind
        # (code-to-code or comment-to-comment). A blank on a code/comment border
        # separates the two deliberately and is left alone.
        def removable_blank_lines(first, second)
          gap = (first.last_line + 1)...second.first_line

          gap.select do |line|
            blank_line?(line) && same_kind_neighbours?(line, first.last_line, second.first_line)
          end
        end

        def same_kind_neighbours?(line, floor, ceiling)
          above = nearest_non_blank(line - 1, floor, -1)
          below = nearest_non_blank(line + 1, ceiling, 1)
          line_kind(above) == line_kind(below)
        end

        def nearest_non_blank(start_line, boundary, step)
          line = start_line
          line += step while line != boundary && blank_line?(line)
          line
        end

        def line_kind(line)
          return :comment if processed_source.lines[line - 1].strip.start_with?('#')

          :code
        end

        def blank_line?(line)
          processed_source.lines[line - 1].strip.empty?
        end

        def line_range_with_newline(line)
          line_range = processed_source.buffer.line_range(line)
          line_range.resize(line_range.length + 1)
        end
      end
    end
  end
end
