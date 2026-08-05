# frozen_string_literal: true

require 'rubocop'

module RuboCop
  module Cop
    module Style
      # Forbids delegation — a class answering a question that belongs to a
      # collaborator. The community name for the smell is Fowler's Middle Man,
      # and the prescribed refactoring is Remove Middle Man: delete the
      # forwarder and let the caller navigate to the object that knows.
      #
      # Two shapes are flagged. The macro family (`delegate`,
      # `delegate_missing_to`, `def_delegator`/`def_delegators`,
      # `DelegateClass`) and an instance method whose entire body forwards the
      # same message to a collaborator. The second is the same defect: writing
      # the forwarder by hand changes what `grep` finds, not what the class
      # claims to be responsible for.
      #
      # @example
      #   # bad
      #   delegate :name, to: :commission
      #
      #   # bad — same promise, written by hand
      #   def name
      #     commission.name
      #   end
      #
      #   # good — the caller navigates
      #   statement.commission.name
      #
      class DisallowDelegate < ::RuboCop::Cop::Base
        MACRO_MSG = 'Do not use automatic delegation. Delete the forwarder and let the caller navigate.'
        FORWARDER_MSG = 'Do not forward a collaborator\'s message. Delete the forwarder and let the caller navigate.'

        RESTRICT_ON_SEND = %i[delegate delegate_missing_to def_delegator def_delegators DelegateClass].freeze

        def on_send(node)
          return unless node.receiver.nil?

          add_offense(node, message: MACRO_MSG)
        end

        def on_def(node)
          return unless forwards_own_message?(node.body, node.method_name)

          add_offense(node.loc.name, message: FORWARDER_MSG)
        end

        private

        def forwards_own_message?(body, method_name)
          return false if body.nil?
          return false unless body.send_type?
          return false if body.receiver.nil?

          body.method?(method_name)
        end
      end
    end
  end
end
