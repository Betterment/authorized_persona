# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "authorized_persona/version"

Gem::Specification.new do |spec|
  spec.name          = "authorized_persona"
  spec.version       = AuthorizedPersona::VERSION
  spec.authors       = ["John Mileham"]
  spec.email         = ["john@betterment.com"]

  spec.summary     = "the simplest authorization library you will ever love"
  spec.description = "AuthorizedPersona is a rails implementation of Betterment's Persona Centric Authorization pattern"
  spec.homepage    = "https://github.com/Betterment/authorized_persona"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.2"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  rails_version_range = [">= 7.2", "< 8.1"]

  spec.add_dependency "railties", *rails_version_range

  spec.add_development_dependency "activemodel", *rails_version_range
  spec.add_development_dependency "appraisal"
  spec.add_development_dependency "betterlint"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.metadata['rubygems_mfa_required'] = 'true'
end
