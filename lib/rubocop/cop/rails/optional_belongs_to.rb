# frozen_string_literal: true

require 'rubocop'

module RuboCop
  module Cop
    module Rails
      # Requires `belongs_to` to declare `optional: true`. The 4Shark convention
      # is to skip Rails' automatic presence/existence validation (a SELECT per
      # record) and validate presence manually with `validates :x_id, presence: true`.
      #
      # Scoped to `app/models` via the `Include` config.
      #
      # @example
      #   # bad
      #   belongs_to :user
      #
      #   # good
      #   belongs_to :user, optional: true
      #
      class OptionalBelongsTo < ::RuboCop::Cop::Base
        MSG = 'Declare `belongs_to` with `optional: true` and validate presence manually.'

        def self.default_configuration
          super.merge(
            'Include' => ['app/models/**/*.rb']
          )
        end

        def on_send(node)
          return unless node.method?(:belongs_to)
          return if optional_true?(node)

          add_offense(node.loc.selector)
        end

        private

        def optional_true?(node)
          kwargs = node.last_argument
          return false if !kwargs || !kwargs.hash_type?

          kwargs.pairs.any? { |pair| pair.key.value == :optional && pair.value.true_type? }
        end
      end
    end
  end
end
