# frozen_string_literal: true

require 'rubocop'

module RuboCop
  module Cop
    module RSpec
      # Forbids conditional logic (`if`/`case`) inside a `let`/`let!` block.
      # Branching object setup belongs in separate `context` blocks, not in a
      # single `let`. Ternaries are allowed.
      #
      # @example
      #   # bad
      #   let(:user) do
      #     if admin?
      #       create(:user, :admin)
      #     else
      #       create(:user)
      #     end
      #   end
      #
      #   # good — one context each
      #   context 'when admin' do
      #     let(:user) { create(:user, :admin) }
      #   end
      #
      class ConditionalInLet < ::RuboCop::Cop::Base
        MSG = 'Do not put conditional logic in a `let` — use separate contexts.'

        LET_METHODS = %i[let let!].freeze

        def on_block(node)
          return unless let_block?(node)

          body = node.body
          return unless body

          body.each_node(:if, :case) do |conditional|
            next if conditional.if_type? && conditional.ternary?

            add_offense(conditional.loc.keyword)
          end
        end

        alias on_numblock on_block
        alias on_itblock on_block

        private

        def let_block?(node)
          send = node.send_node
          LET_METHODS.include?(send.method_name) && send.receiver.nil?
        end
      end
    end
  end
end
