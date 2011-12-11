require 'rubygems'

Gem::Specification.new do |s|
	s.name = 'svn'
	s.summary = 'Ruby bindings for SVN based on FFI'
	s.version = '0.1.0'
	s.author = 'Ryan Blue'
	s.email = 'rdblue@gmail.com'
	s.homepage = 'http://github.com/codefoundry/svn'
	s.files = Dir['lib/**/*.rb'] #+ Dir['test/*.rb'] + ['test/run']
	#s.test_file = 'test/run'
	s.add_dependency 'ffi', '~> 1.0'
  s.has_rdoc = true
	s.extra_rdoc_files = ['README']
end
