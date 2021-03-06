# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'wesm/version'

Gem::Specification.new do |spec|
  spec.name          = 'wesm'
  spec.version       = Wesm::VERSION
  spec.authors       = ['arthurweisz']
  spec.email         = ['cloudsong1@yandex.ru']

  spec.summary       = 'Wisely Explicit State Machine'
  spec.description   = 'Wisely Explicit State Machine'
  spec.homepage      = ''

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.12'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'pry', '~> 0.10'
  spec.required_ruby_version = '>= 1.9'
end
