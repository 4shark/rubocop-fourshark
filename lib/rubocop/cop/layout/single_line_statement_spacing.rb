# frozen_string_literal: true

require 'rubocop'

module RuboCop
  module Cop
    module Layout
      # Forbids a blank line between two consecutive single-line statements —
      # they are one run, so the blank reveals nothing. A blank that separates
      # code from an adjacent comment is kept, as is one owned by another cop
      # (a guard clause, a flow-control statement, an access modifier, the end
      # of an RSpec `let`/`subject`/hook/example run, the end of a module
      # inclusion or attribute accessor run, a Bundler gem section) or one
      # beside a multi-line or heredoc neighbour. Autocorrects by removing it.
      class SingleLineStatementSpacing < ::RuboCop::Cop::Base
        extend ::RuboCop::Cop::AutoCorrector
        ACCESS_MODIFIERS = %i[private protected public module_function].freeze
        FLOW_CONTROL_METHODS = %i[raise fail throw].freeze
        FLOW_CONTROL_TYPES = %i[return next break redo retry].freeze
        MSG = 'Remove the blank line between consecutive single-line statements.'
        ONE_LINER_RUN_COPS = { example: 'RSpec/EmptyLineAfterExample', hook: 'RSpec/EmptyLineAfterHook' }.freeze

        RSPEC_KINDS = {
          after: :hook,
          append_after: :hook,
          append_before: :hook,
          around: :hook,
          before: :hook,
          context: :example_group,
          describe: :example_group,
          example: :example,
          example_group: :example_group,
          fcontext: :example_group,
          fdescribe: :example_group,
          feature: :example_group,
          fexample: :example,
          ffeature: :example_group,
          fit: :example,
          focus: :example,
          fscenario: :example,
          fspecify: :example,
          it: :example,
          its: :example,
          let: :let,
          let!: :let,
          pending: :example,
          prepend_after: :hook,
          prepend_before: :hook,
          scenario: :example,
          shared_context: :example_group,
          shared_examples: :example_group,
          shared_examples_for: :example_group,
          skip: :example,
          specify: :example,
          subject: :subject,
          subject!: :subject,
          xcontext: :example_group,
          xdescribe: :example_group,
          xexample: :example,
          xfeature: :example_group,
          xit: :example,
          xscenario: :example,
          xspecify: :example
        }.freeze

        STATEMENT_RUN_KINDS = {
          attr: :attribute_accessor,
          attr_accessor: :attribute_accessor,
          attr_reader: :attribute_accessor,
          attr_writer: :attribute_accessor,
          extend: :module_inclusion,
          include: :module_inclusion,
          prepend: :module_inclusion
        }.freeze

        def on_begin(node)
          node.children.each_cons(2) do |first, second|
            next unless first.is_a?(::RuboCop::AST::Node) && second.is_a?(::RuboCop::AST::Node)
            next if structural?(first) || structural?(second)
            next if rspec_run_ends?(first, second) || statement_run_ends?(first, second)
            next if gem_section_boundary?(first, second)

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

        # The `RSpec/EmptyLineAfter*` cops demand a blank after the last `let`,
        # `subject`, hook, example or example group of a run; removing it makes the two cops fight.
        def rspec_run_ends?(first, second)
          kind = rspec_kind(first)

          return false if kind.nil?
          return true if kind != rspec_kind(second)

          !one_liner_run_allowed?(kind)
        end

        # Only `let`s always run together; hooks and examples do while their cop keeps
        # `AllowConsecutiveOneLiners`, and subjects and example groups never do.
        def one_liner_run_allowed?(kind)
          return true if kind == :let

          cop_name = ONE_LINER_RUN_COPS[kind]

          return false if cop_name.nil?

          config.for_cop(cop_name).fetch('AllowConsecutiveOneLiners', true)
        end

        def rspec_kind(node)
          call =
            if node.any_block_type?
              node.send_node
            else
              node
            end

          return nil if !call.send_type? || call.receiver

          RSPEC_KINDS[call.method_name]
        end

        # `Layout/EmptyLinesAfterModuleInclusion` and `Layout/EmptyLinesAroundAttributeAccessor`
        # demand a blank after the last `include`/`extend`/`prepend` or `attr_*` of a run.
        def statement_run_ends?(first, second)
          kind = statement_run_kind(first)

          return false if kind.nil?

          kind != statement_run_kind(second)
        end

        def statement_run_kind(node)
          return nil if !node.send_type? || node.receiver

          STATEMENT_RUN_KINDS[node.method_name]
        end

        # `Bundler/OrderedGems` reads a blank between two `gem` lines as a section break.
        def gem_section_boundary?(first, second)
          gem_declaration?(first) && gem_declaration?(second)
        end

        def gem_declaration?(node)
          node.send_type? && node.receiver.nil? && node.method?(:gem)
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
