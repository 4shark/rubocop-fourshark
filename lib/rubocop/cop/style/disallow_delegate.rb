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
      # A macro aimed at `:class` reaches the same place and is exempt for the
      # same reason. Remove Middle Man has nothing to prescribe here: there is no
      # third object for the caller to navigate to, so the only alternatives are
      # the macro and a hand-written body that says exactly what the macro says.
      # Between those two the macro is the better spelling, and flagging it while
      # exempting the body would push every author toward the longer one.
      #
      # `each` in a class that includes or prepends `Enumerable` is the module's
      # required contract, not delegation. The class has no interface without it
      # — every method `Enumerable` provides is built on `each` — so the class is
      # implementing its own interface rather than answering for a collaborator.
      # It is not flagged. Any other method in such a class still is, and so is
      # `each` in a singleton class: an instance-side mixin obliges the instance,
      # never the singleton.
      #
      # A body that passes the object's own state as an argument to a DIRECT
      # collaborator is not a pass-through. Middle Man is a method that
      # republishes a collaborator's answer verbatim, which the caller could
      # reach by navigating; a method that supplies its own attributes
      # contributes something the caller would otherwise have to reach in and
      # take, and the result is a simpler API on the object that owns the data.
      #
      # Own state is an instance variable, `self`, or a receiverless call,
      # reached directly, through a wrapper, or through a call on it — `record`,
      # `record.owner_id` and `[record.owner_id]` all carry the object's own
      # data. A method PARAMETER does not: it arrives as an `lvar`, so a setter
      # handing its argument to a collaborator stays flagged.
      #
      # Two limits keep the exemption from swallowing the rule.
      #
      # The receiver must not itself be a chain. Remove Middle Man on a message
      # chain IS the caller navigating, so composing own state does not excuse
      # it.
      #
      # An argument rooted at the collaborator being forwarded to does not earn
      # the exemption. `author.name(author.locale)` hands the collaborator back
      # its own data, which is the echo this rule forbids, not composition, so
      # with no other argument to carry it the forward stays flagged. Rooted at
      # the object's OWN state the argument may be a chain of any depth — the
      # object still supplied what the collaborator needed, and how far it
      # reached inside itself to build the value is its own business.
      #
      # A forward to a collaborator that passes NO argument is the one that
      # republishes, and it is always flagged. That is the line — supplying data
      # the collaborator needs is composition, echoing back what the collaborator
      # already knows is delegation.
      #
      # @example
      #   # bad
      #   delegate :name, to: :author
      #
      #   # bad — same promise, written by hand
      #   def name
      #     author.name
      #   end
      #
      #   # good — the caller navigates
      #   post.author.name
      #
      #   # good — the object answers about itself, not for a collaborator
      #   def lock_key
      #     self.class.lock_key(owner_id: owner_id)
      #   end
      #
      #   # good — aimed at the object's own class, where there is no third
      #   # object to navigate to
      #   delegate :model, to: :class
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
      #     formatter.output(value)
      #   end
      #
      #   # good — names an expression built from its own record; not a forward
      #   def lock_key
      #     Registry.lock_key(owner_id: record.owner_id)
      #   end
      #
      #   # bad — a chain does not stop being a chain because an argument rode along
      #   def starts_at
      #     schedule.window.period.starts_at(calendar)
      #   end
      #
      #   # bad — the argument is the collaborator's own data handed back to it
      #   def name
      #     author.name(author.locale)
      #   end
      #
      class DisallowDelegate < ::RuboCop::Cop::Base
        MACRO_MSG = 'Do not use automatic delegation. Delete the forwarder and let the caller navigate.'
        FORWARDER_MSG = 'Do not forward a collaborator\'s message. Delete the forwarder and let the caller navigate.'

        RESTRICT_ON_SEND = %i[delegate delegate_missing_to def_delegator def_delegators DelegateClass].freeze

        # An argument reaches the body wrapped in one of these when the call site
        # spreads or blocks it, and the wrapper says nothing about whose state it
        # carries.
        ARGUMENT_WRAPPERS = %i[hash pair array splat kwsplat block_pass].freeze

        # @!method mixes_in_enumerable?(node)
        def_node_matcher :mixes_in_enumerable?, <<~PATTERN
          (send nil? {:include :prepend} (const {nil? cbase} :Enumerable))
        PATTERN

        # `delegate` names its target in a `to:` option, wherever that option
        # sits among the forwarded method names.
        # @!method to_option(node)
        def_node_matcher :to_option, <<~PATTERN
          (send nil? :delegate ... (hash <(pair (sym :to) $_) ...>))
        PATTERN

        # The Forwardable macros and `delegate_missing_to` take their target as
        # the first argument. `DelegateClass` names none and never matches.
        # @!method leading_target(node)
        def_node_matcher :leading_target, <<~PATTERN
          (send nil? {:delegate_missing_to :def_delegator :def_delegators} $_ ...)
        PATTERN

        def on_send(node)
          return unless node.receiver.nil?
          return if own_class_target?(node)

          add_offense(node, message: MACRO_MSG)
        end

        def on_def(node)
          return unless forwards_own_message?(node.body, node.method_name)
          return if enumerable_contract?(node)
          return if composes_own_state?(node.body)

          add_offense(node.loc.name, message: FORWARDER_MSG)
        end

        private

        # The target is written as a bare name, so a symbol and a string say the
        # same thing and both are read as one.
        def own_class_target?(node)
          target = to_option(node) || leading_target(node)

          return false if target.nil?
          return false unless target.type?(:sym, :str)

          target.value.to_sym == :class
        end

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

        # The nearest enclosing scope decides, and a singleton class never
        # inherits the instance side's mixin.
        def enumerable_contract?(node)
          return false unless node.method?(:each)

          enclosing = node.each_ancestor(:class, :module, :sclass).first

          return false if enclosing.nil?
          return false if enclosing.sclass_type?

          enumerable_body?(enclosing.body)
        end

        def enumerable_body?(body)
          return false if body.nil?
          return body.children.any? { |child| mixes_in_enumerable?(child) } if body.begin_type?

          mixes_in_enumerable?(body)
        end

        # A body that passes the object's own state is composing, not forwarding:
        # it collapses `owner.collaborator.message(owner.state)` into
        # `owner.message`, so the method hides the passing of a parameter the
        # object itself holds. How far the collaborator sits is not part of that
        # judgement — depth changes the path to the collaborator, never who the
        # answer is about. A body that passes nothing, or passes a parameter the
        # caller handed in, composes nothing and stays an offense at any depth.
        def composes_own_state?(body)
          body.arguments.any? { |argument| own_state?(argument, body.receiver) }
        end

        # A method parameter reaches the body as an `lvar`, so only an instance
        # variable, `self`, or a receiverless call counts as the object's own
        # state — read directly, through a wrapper, or through a call on it.
        # Anything rooted at the collaborator is that collaborator's own data
        # coming back, which is the echo the rule forbids. The first guard
        # refuses anything that is not a node, which covers both the nil child
        # an anonymous block pass carries and a wrapper whose children are raw
        # Ruby values rather than nodes.
        def own_state?(argument, collaborator)
          return false unless argument.is_a?(::RuboCop::AST::Node)
          return false if argument == collaborator
          return true if argument.ivar_type?
          return true if argument.self_type?
          return own_state?(argument.receiver, collaborator) if call_with_receiver?(argument)
          return true if argument.send_type?
          return argument.children.any? { |child| own_state?(child, collaborator) } if wrapper?(argument)

          false
        end

        # `call_type?` is the `send`/`csend` union, so safe navigation counts as
        # the call it is — a `&.` link neither escapes the chain limit nor stops
        # own state from being recognized.
        def call_with_receiver?(node)
          return false unless node.call_type?

          !node.receiver.nil?
        end

        def wrapper?(argument)
          ARGUMENT_WRAPPERS.include?(argument.type)
        end
      end
    end
  end
end
