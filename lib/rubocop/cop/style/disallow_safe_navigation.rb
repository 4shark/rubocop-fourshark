# frozen_string_literal: true

require 'rubocop'

module RuboCop
  module Cop
    module Style
      class DisallowSafeNavigation < ::RuboCop::Cop::Base
        MSG = 'Do not use safe navigation (`&.`). Use explicit conditionals instead.'

        def on_csend(node)
          add_offense(node)
        end
      end
    end
  end
end
