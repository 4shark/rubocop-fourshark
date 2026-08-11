# frozen_string_literal: true

require 'rubocop'

module RuboCop
  module Cop
    module Layout
      # Requires a blank line before a guard clause that follows ordinary code.
      # A guard clause breaks the flow, so it has to be findable at a glance
      # rather than read for — the same reason a multi-line statement is set off
      # from its neighbours.
      #
      # Consecutive guard clauses are one block and stay glued together: the run
      # is what the reader scans, and blank lines inside it would break the shape
      # instead of revealing it. Only the first clause of a run needs the blank
      # line above, and a guard that opens a body needs none because the `def`
      # or `do` already delimits it.
      #
      # What counts as a guard clause is `guard_clause?` from `rubocop-ast`,
      # which covers `return`, `break`, `next`, `raise` and `fail`.
      #
      # The blank line *after* the run is the stock
      # `Layout/EmptyLineAfterGuardClause`, which this cop mirrors rather than
      # replaces — enable both to get a run that is set off on both sides.
      #
      # Detection-only (no autocorrect), matching the sibling
      # `Layout/MultilineStatementSpacing`: where a comment sits above the
      # clause the blank line belongs above the comment, and that placement
      # needs validation against the real repos before it is applied for anyone.
      #
      # @example
      #   # bad
      #   def foo
      #     bar
      #     return if baz?
      #
      #     qux
      #   end
      #
      #   # good
      #   def foo
      #     bar
      #
      #     return if baz?
      #
      #     qux
      #   end
      #
      #   # good — a run of guard clauses stays together
      #   def foo
      #     return if baz?
      #     return if qux?
      #
      #     bar
      #   end
      #
      #   # good — nothing above it to separate from
      #   def foo
      #     return if baz?
      #
      #     bar
      #   end
      #
      class EmptyLineBeforeGuardClause < ::RuboCop::Cop::Base
        MSG = 'Add a blank line before the guard clause.'

        def on_begin(node)
          node.children.each_cons(2) do |previous, current|
            next unless guard_clause?(current)
            next if guard_clause?(previous)
            next if blank_line_between?(previous, current)

            add_offense(current)
          end
        end

        private

        def guard_clause?(node)
          return false unless node.is_a?(::RuboCop::AST::Node)
          return false unless node.if_type?

          branch = node.if_branch

          return false if branch.nil?

          branch.guard_clause?
        end

        def blank_line_between?(previous, current)
          return false if current.first_line - previous.last_line < 2

          ((previous.last_line + 1)...current.first_line).any? do |line|
            processed_source.lines[line - 1].strip.empty?
          end
        end
      end
    end
  end
end
