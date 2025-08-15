# frozen_string_literal: true

require_relative "lib/duo_universal_ruby/version"

Gem::Specification.new do |spec|
  spec.name          = "duo_universal_ruby"
  spec.version       = DuoUniversalRuby::VERSION
  spec.authors       = ["Todd Parsnick"]
  spec.email         = ["tparsnick@gmail.com"]

  spec.summary       = "Easily add two-factor authentication to any Ruby web authentication flow using a Web SDKv4 app with the universal prompt in Duo."
  spec.description   = spec.summary
  spec.homepage      = "https://github.com/tparsnick/duo_universal_ruby"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.2.2"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"]   = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  # Files included in the gem
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci Gemfile])
    end
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_runtime_dependency "jwt", ">= 2.2.2" # Required by Client class

  # Optional: Add other runtime deps here if needed, e.g.:
  # spec.add_runtime_dependency "httparty", ">= 0"
end

