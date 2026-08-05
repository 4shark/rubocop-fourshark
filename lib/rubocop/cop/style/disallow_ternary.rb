# frozen_string_literal: true

require 'rubocop'

module RuboCop
  module Cop
    module Style
      # Forbids the ternary conditional. `?` and `:` are punctuation that already
      # mean other things in Ruby (`valid?`, `:symbol`), so the reader
      # disambiguates characters before seeing the branch — and the ternary hides
      # a branch inside an expression, where skimming misses it. Inside a hash or
      # an argument list, extract a named local and branch on it.
      #
      # @example
      #   # bad
      #   status = saved ? :applied : :failed
      #
      #   # good
      #   if saved
      #     status = :applied
      #   else
      #     status = :failed
      #   end
      #
      class DisallowTernary < ::RuboCop::Cop::Base
        MSG = 'Do not use the ternary conditional. Use an explicit `if`/`else` instead.'

        def on_if(node)
          add_offense(node) if node.ternary?
        end
      end
    end
  end
end
