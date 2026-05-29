# frozen_string_literal: true

require 'rubocop'

module RuboCop
  module Cop
    module RSpec
      # Requires `let`/`let!` to be declared at the top of the example group,
      # never inside a `context`. All setup objects live at the top level.
      #
      # @example
      #   # bad
      #   context 'when disabled' do
      #     let(:user) { create(:user) }
      #   end
      #
      #   # good
      #   let(:user) { create(:user) }
      #
      #   context 'when disabled' do
      #     before { user.disable }
      #   end
      #
      class LetNotInContext < ::RuboCop::Cop::Base
        MSG = 'Declare `let` at the top level, not inside a `context`.'

        LET_METHODS = %i[let let!].freeze

        def on_send(node)
          return unless LET_METHODS.include?(node.method_name) && node.receiver.nil?
          return unless node.each_ancestor(:block).any? { |ancestor| context_block?(ancestor) }

          add_offense(node.loc.selector)
        end

        private

        def context_block?(node)
          send = node.send_node
          send.method?(:context) && send.receiver.nil?
        end
      end
    end
  end
end
