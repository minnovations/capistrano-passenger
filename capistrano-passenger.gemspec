lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |gem|
  gem.name          = 'capistrano-passenger'
  gem.version       = '1.0.0'
  gem.authors       = ['M Innovations']
  gem.email         = ['contact@minnovations.sg']
  gem.description   = 'Capistrano Passenger tasks'
  gem.summary       = 'Capistrano Passenger tasks'

  gem.files         = `git ls-files`.split($/)
  gem.require_paths = ['lib']

  gem.add_dependency 'capistrano', '~> 3.4'
end
