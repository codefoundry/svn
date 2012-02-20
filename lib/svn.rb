require 'rubygems'
require 'ffi'

require 'svn/utils'
require 'svn/misc'
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

  def self.create( path )
    Repo.create( path )
  end

  def self.open( path )
    Repo.open( path )
  end
end
