# frozen_string_literal: true

require 'rubocop'

module RuboCop
  module Cop
    module Style
      class DisallowTry < ::RuboCop::Cop::Base
        MSG = 'Do not use `try` or `try!`. Use explicit conditionals instead.'

        RESTRICT_ON_SEND = %i[try try!].freeze

        def on_send(node)
          add_offense(node)
        end
      end
    end
  end
end
