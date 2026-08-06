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
      # `each` in a class that includes `Enumerable` is the module's required
      # contract, not delegation. The class has no interface without it — every
      # method `Enumerable` provides is built on `each` — so the class is
      # implementing its own interface rather than answering for a collaborator.
      # It is not flagged. Any other method in such a class still is.
      #
      # A body that passes the object's own state as an argument is not a
      # pass-through. Middle Man is a method that republishes a collaborator's
      # answer verbatim, which the caller could reach by navigating; a method
      # that supplies its own attributes contributes something the caller would
      # otherwise have to reach in and take, and the result is a simpler API on
      # the object that owns the data. Own state is an instance variable or a
      # receiverless call — a method parameter forwarded through is not, so a
      # setter passing its argument along stays flagged.
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
      #   # good — `each` is the Enumerable contract this class implements
      #   class SearchResult
      #     include Enumerable
      #
      #     def each(&)
      #       results.each(&)
      #     end
      #   end
      #
      #   # good — composes its own attribute, so the caller cannot just navigate
      #   def output
      #     variable.output(value)
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

        # @!method includes_enumerable?(node)
        def_node_matcher :includes_enumerable?, <<~PATTERN
          (send nil? :include (const {nil? cbase} :Enumerable))
        PATTERN

        def on_def(node)
          return unless forwards_own_message?(node.body, node.method_name)
          return if enumerable_contract?(node)
          return if composes_own_state?(node.body)

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

        def enumerable_contract?(node)
          return false unless node.method?(:each)

          enclosing = node.each_ancestor(:class, :module).first
          return false if enclosing.nil?

          enumerable_body?(enclosing.body)
        end

        def enumerable_body?(body)
          return false if body.nil?
          return body.children.any? { |child| includes_enumerable?(child) } if body.begin_type?

          includes_enumerable?(body)
        end

        def composes_own_state?(body)
          body.arguments.any? { |argument| own_state?(argument) }
        end

        # A method parameter reaches the body as an `lvar`, so only an instance
        # variable or a receiverless call counts as the object's own state.
        def own_state?(argument)
          return true if argument.ivar_type?
          return true if argument.send_type? && argument.receiver.nil?
          return argument.values.any? { |value| own_state?(value) } if argument.hash_type?

          false
        end
      end
    end
  end
end
