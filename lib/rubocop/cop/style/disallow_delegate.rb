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
      # `self.class` is not a collaborator — it is the object's own class. An
      # instance method that composes its own attributes into a same-named class
      # method answers for a domain it owns, so it is not delegation and is not
      # flagged.
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
      #   # good — the object answers about itself, not for a collaborator
      #   def lock_key
      #     self.class.lock_key(company_id: company_id)
      #   end
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
          return false if own_class?(body.receiver)

          body.method?(method_name)
        end

        def own_class?(receiver)
          return false unless receiver.send_type?
          return false unless receiver.method?(:class)
          return false if receiver.receiver.nil?

          receiver.receiver.self_type?
        end
      end
    end
  end
end
