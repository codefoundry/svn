require 'rubygems'
require 'ffi'

$: << 'lib'
require 'svn/utils'
require 'svn/pools'
require 'svn/errors'
require 'svn/streams'
require 'svn/diffs'
require 'svn/roots'
require 'svn/revisions'
require 'svn/repos'

# General Svn docs here!
module Svn
end

if $0 == __FILE__
  d = Svn::Diff.diff( File.expand_path(ARGV[0]), File.expand_path(ARGV[1]) )
  puts d.unified.tap { |io| io.rewind }.read
end
