# frozen_string_literal: true

require 'rubocop'

module RuboCop
  module Cop
    module Rails
      # Requires class-level macro declarations of the same kind to be sorted
      # alphabetically by their first symbol argument. Checked per macro name:
      # all `belongs_to` sorted among themselves, all `validates` sorted, etc.
      #
      # `:through` associations are sorted as a separate trailing group (a
      # `:through` association must be declared after its target association),
      # not interleaved with the regular declarations.
      #
      # Other exceptions (lifecycle callbacks, other dependency-ordered items)
      # are NOT modelled — this is an experimental cop; if it flags more
      # legitimate cases than it helps, drop it.
      #
      # @example
      #   # bad
      #   validates :name
      #   validates :email
      #
      #   # good
      #   validates :email
      #   validates :name
      #
      class OrderedMacros < ::RuboCop::Cop::Base
        MSG = 'Sort `%<macro>s` declarations alphabetically (`%<name>s` should come before `%<previous>s`).'

        MACROS = %i[belongs_to has_one has_many has_and_belongs_to_many validates scope].freeze

        def self.default_configuration
          super.merge('Include' => ['app/models/**/*.rb'])
        end

        def on_class(node)
          body = node.body
          return unless body

          statements = if body.begin_type?
                         body.children
                       else
                         [body]
                       end

          MACROS.each do |macro|
            calls = statements.select { |statement| macro_call?(statement, macro) }
            regular, through = calls.partition { |call| !through_option?(call) }
            flag_unsorted(regular)
            flag_unsorted(through)
          end
        end

        private

        # A `:through` association must be declared after its target association,
        # so it forms a separate trailing group sorted among itself — never
        # interleaved with (or compared against) the regular declarations.
        def through_option?(node)
          node.arguments.any? do |argument|
            argument.hash_type? && argument.keys.any? { |key| key.value == :through }
          end
        end

        def flag_unsorted(calls)
          calls.each_cons(2) do |previous, current|
            previous_name = macro_name(previous)
            current_name = macro_name(current)
            next if current_name >= previous_name

            add_offense(
              current.loc.selector,
              message: format(MSG, macro: current.method_name, name: current_name, previous: previous_name)
            )
          end
        end

        def macro_call?(node, macro)
          return false unless node.is_a?(::RuboCop::AST::Node) && node.send_type?
          return false unless node.method?(macro)

          first = node.first_argument
          first && first.sym_type?
        end

        def macro_name(node)
          node.first_argument.value.to_s
        end
      end
    end
  end
end
