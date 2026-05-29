# frozen_string_literal: true

require 'lint_roller'

module RuboCop
  module Fourshark
    # A plugin that integrates rubocop-fourshark with RuboCop's plugin system.
    class Plugin < LintRoller::Plugin
      def about
        LintRoller::About.new(
          name: 'rubocop-fourshark',
          version: VERSION,
          homepage: 'https://github.com/4shark/rubocop-fourshark',
          description: "4Shark's Ruby, Rails, and RSpec conventions as RuboCop cops."
        )
      end

      def supported?(context)
        context.engine == :rubocop
      end

      def rules(_context)
        LintRoller::Rules.new(
          type: :path,
          config_format: :rubocop,
          value: Pathname.new(__dir__).join('../../../config/default.yml')
        )
      end
    end
  end
end
