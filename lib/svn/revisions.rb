require 'time'
require 'rubygems'
require 'ffi'

module Svn #:nodoc:

  class Revision < Root

    LOG_PROP_NAME = 'svn:log'
    AUTHOR_PROP_NAME = 'svn:author'
    TIMESTAMP_PROP_NAME = 'svn:date'

    attr_reader :num
    attr_reader :fs

    def initialize( ptr, fs, pool )
      super( ptr )
      @fs = fs
      @pool = pool
      @num = revnum
    end

    def to_i
      @num
    end

    module C
      extend FFI::Library
      ffi_lib 'libsvn_fs-1.so.1'

      typedef :pointer, :out_pointer
      typedef Pool, :pool
      typedef CError.by_ref, :error
      typedef Root, :root
      typedef :long, :revnum
      typedef :string, :path
      typedef Repo::FileSystem, :fs
      typedef CountedString, :counted_string

      attach_function :revnum,
          :svn_fs_revision_root_revision,
          [ :root ],
          :revnum

      attach_function :prop,
          :svn_fs_revision_prop,
          [ :out_pointer, :fs, :revnum, :path, :pool ],
          :error
    end

    # use the C module for all bound methods
    bind_to C

    # gets the numeric identifier for this revision
    bind :revnum
    private :revnum

    # returns the revision property +name+
    bind( :prop,
        :returning => CountedString,
        :before_return => :to_s,
        :validate => Error.return_check
      ) { |out, this, path| [ out, fs, num, path, pool ] }

    def log
      prop( LOG_PROP_NAME )
    end

    def author
      prop( AUTHOR_PROP_NAME )
    end

    def timestamp
      Time.parse( prop( TIMESTAMP_PROP_NAME ) )
    end

  end

end
