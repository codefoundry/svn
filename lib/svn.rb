require 'rubygems'
require 'ffi'

require 'svn/utils'
require 'svn/errors'
require 'svn/pools'
require 'svn/apr_utils'
require 'svn/counted_strings'

# General Svn docs here!
module Svn
  autoload :Stream, 'svn/streams'
  autoload :Log, 'svn/logs'
  autoload :Repo, 'svn/repos'
  autoload :Root, 'svn/roots'
  autoload :Revision, 'svn/revisions'
  autoload :Diff, 'svn/diffs'
end

if $0 == __FILE__
  d = Svn::Diff.diff( File.expand_path(ARGV[0]), File.expand_path(ARGV[1]) )
  puts d.unified.tap { |io| io.rewind }.read
end
