# -*- encoding: utf-8 -*-
require File.expand_path('../lib/logjam_zeromq_amqp_bridge/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Stefan Kaes"]
  gem.email         = ["stefan.kaes@xing.com"]
  gem.description   = %q{TODO: Write a gem description}
  gem.summary       = %q{TODO: Write a gem summary}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "logjam_zeromq_amqp_bridge"
  gem.require_paths = ["lib"]
  gem.version       = LogjamZeromqAmqpBridge::VERSION

  gem.add_runtime_dependency "zmq"
  gem.add_runtime_dependency "bunny"

end
