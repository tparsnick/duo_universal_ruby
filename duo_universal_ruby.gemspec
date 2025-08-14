# frozen_string_literal: true

require_relative "lib/duo_universal_ruby/version"

Gem::Specification.new do |spec|
  spec.name = "duo_universal_ruby"
  spec.version = DuoUniversalRuby::VERSION
  spec.authors = ["Todd Parsnick"]
  spec.email = ["tparsnick@gmail.com"]

  spec.summary = "Easily add two-factor authentication to any Ruby web authentication flow using a Web SDKv4 app with the universal prompt in Duo."
  spec.description = "Easily add two-factor authentication to any Ruby web authentication flow using a Web SDKv4 app with the universal prompt in Duo."
  spec.homepage = 'https://github.com/tparsnick/duo_universal_ruby'
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.2"

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = 'https://github.com/tparsnick/duo_universal_ruby'
  spec.metadata["changelog_uri"] = 'https://github.com/tparsnick/duo_universal_ruby/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_runtime_dependency 'jwt'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
