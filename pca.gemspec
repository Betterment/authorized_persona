lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "pca/version"

Gem::Specification.new do |spec|
  spec.name          = "pca"
  spec.version       = PCA::VERSION
  spec.authors       = ["John Mileham"]
  spec.email         = ["john@betterment.com"]

  spec.summary     = "Persona Centric Authorization"
  spec.description = "PCA (Persona Centric Authorization) is the simplest turnkey authorization library you will ever love"
  spec.homepage    = "https://github.com/Betterment/pca"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  rails_version_range = [">= 5.2.3", "< 7"]

  spec.add_dependency "activemodel",   *rails_version_range
  spec.add_dependency "activesupport", *rails_version_range
  spec.add_dependency "railties",      *rails_version_range

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop-betterment"
end
