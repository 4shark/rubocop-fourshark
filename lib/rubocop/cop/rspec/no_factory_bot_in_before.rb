# frozen_string_literal: true

require 'rubocop'

module RuboCop
  module Cop
    module RSpec
      # Forbids object creation (`create`/`build`/`create_list`/`build_list`)
      # inside a `before` block. Object creation belongs in `let`; `before` is
      # for actions only.
      #
      # @example
      #   # bad
      #   before { @user = create(:user) }
      #
      #   # good
      #   let(:user) { create(:user) }
      #
      class NoFactoryBotInBefore < ::RuboCop::Cop::Base
        MSG = 'Do not create objects in `before` — use `let` for object creation.'

        CREATION_METHODS = %i[create build create_list build_list].freeze

        def on_block(node)
          return unless before_block?(node)

          node.each_node(:send) do |send|
            next unless CREATION_METHODS.include?(send.method_name) && send.receiver.nil?

            add_offense(send.loc.selector)
          end
        end

        alias on_numblock on_block
        alias on_itblock on_block

        private

        def before_block?(node)
          send = node.send_node
          send.method?(:before) && send.receiver.nil?
        end
      end
    end
  end
end
