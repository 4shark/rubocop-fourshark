# frozen_string_literal: true

require_relative 'lib/rubocop/fourshark/version'

Gem::Specification.new do |spec|
  spec.name = 'rubocop-fourshark'
  spec.version = RuboCop::Fourshark::VERSION
  spec.authors = ['Paulo Ribeiro']
  spec.email = ['plribeiro3000@gmail.com']

  spec.summary = "RuboCop extension enforcing 4Shark's Ruby, Rails, and RSpec conventions."
  spec.homepage = 'https://github.com/4shark/rubocop-fourshark'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/4shark/rubocop-fourshark/blob/main'
  spec.metadata['changelog_uri'] = 'https://github.com/4shark/rubocop-fourshark/blob/main/CHANGELOG.md'
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)

  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile renovate.json .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end

  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.metadata['default_lint_roller_plugin'] = 'RuboCop::Fourshark::Plugin'

  spec.add_dependency 'lint_roller', '~> 1.1'
  spec.add_dependency 'rubocop', '>= 1.87'

  # Umbrella: bundle the upstream RuboCop plugins so consuming repos depend on
  # only rubocop-fourshark. Each repo still lists the plugins in its own
  # .rubocop.yml (lint_roller has no transitive plugin activation).
  spec.add_dependency 'rubocop-factory_bot'
  spec.add_dependency 'rubocop-graphql'
  spec.add_dependency 'rubocop-performance'
  spec.add_dependency 'rubocop-rails'
  spec.add_dependency 'rubocop-rspec'
  spec.add_dependency 'rubocop-rspec_rails'
end
