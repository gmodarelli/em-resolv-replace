# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{em-resolv-replace}
  s.version = "1.1.3"
  s.authors = ["Mike Perham"]
  s.email = %q{mperham@gmail.com}
  s.extra_rdoc_files = [
    "LICENSE",
     "History.rdoc",
     "README.rdoc"
  ]
  s.files = [
    ".document",
     ".gitignore",
     "History.rdoc",
     "LICENSE",
     "README.rdoc",
     "Rakefile",
     "VERSION",
     "lib/em-dns-resolver.rb",
     "lib/em-resolv-replace.rb",
     "test/helper.rb",
     "test/test_em-resolv-replace.rb"
  ]
  s.homepage = %q{http://github.com/mperham/em-resolv-replace}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.summary = %q{EventMachine-aware DNS lookup for Ruby}
  s.test_files = [
    "test/helper.rb",
     "test/test_em-resolv-replace.rb"
  ]

  s.add_development_dependency(%q<eventmachine>, [">= 0"])
  s.add_development_dependency(%q<shoulda>, ["2.11.3"])
  s.add_development_dependency(%q<mocha>, ["0.14.0"])
end

