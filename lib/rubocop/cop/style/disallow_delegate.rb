# frozen_string_literal: true

require 'rubocop'

module RuboCop
  module Cop
    module Style
      # Forbids automatic delegation — `delegate`, `delegate_missing_to`,
      # `def_delegator`/`def_delegators` (Forwardable) and `DelegateClass`.
      # A delegation macro is a call, not a definition, so `grep 'def foo'` and
      # jump-to-definition find nothing; the community name for the smell is
      # Fowler's Middle Man. Write the method, or delete the wrapper and let the
      # caller ask the object that knows.
      #
      # @example
      #   # bad
      #   delegate :commission, to: :user_commission
      #
      #   # good
      #   def commission
      #     user_commission.commission
      #   end
      #
      class DisallowDelegate < ::RuboCop::Cop::Base
        MSG = 'Do not use automatic delegation. Write the method explicitly instead.'

        RESTRICT_ON_SEND = %i[delegate delegate_missing_to def_delegator def_delegators DelegateClass].freeze

        def on_send(node)
          return unless node.receiver.nil?

          add_offense(node)
        end
      end
    end
  end
end
