require 'rubygems'
require 'ffi'

module Svn #:nodoc:

  # A subverion repository object
  #
  # This represents both the repository and the filesystem
  class Repo < FFI::AutoPointer

    class << self
      def open( path, pool=RootPool )
        # we may need to call find_root_path for this, if C.open expects a
        # repository root path
        out = FFI::MemoryPointer.new( :pointer )

        Error.check_and_raise(
            C.open( out, path, nil, pool )
          )

        new( out.read_pointer )
      end

      def create( path, pool=RootPool )
        out = FFI::MemoryPointer.new( :pointer )

        Error.check_and_raise(
            C.create( out, path, nil, nil, nil, nil, pool )
          )

        new( out.read_pointer )
      end

      def delete( path, pool=RootPool )
        Error.check_and_raise(
            C.delete( path, pool )
          )
      end
    end

    # return the repository's filesystem
    def filesystem
      @fs ||= C.filesystem( self )
    end
    alias_method :fs, :filesystem

    # A filesystem object.  Repositories completely encapsulate the filesystem,
    # so it is unnecessary to use it directly.
    class FileSystem < FFI::AutoPointer
    end

    module C
      extend FFI::Library
      ffi_lib 'libsvn_repos-1.so.1'
      ffi_lib 'libsvn_fs-1.so.1'

      typedef :out_pointer, :pointer
      typedef Pool, :pool
      typedef CError.by_ref, :error
      typedef FileSystem, :filesystem
      typedef Repo, :repo
      typedef :long, :revnum

      # repository functions
      attach_function :open,
          :svn_repos_open2,
          [ :out_pointer, :string, :pointer, :pool ],
          :error
      attach_function :create,
          :svn_repos_create,
          [ :out_pointer, :string, :pointer, :pointer, :pointer, :pointer, :pool ],
          :error
      attach_function :delete,
          :svn_repos_delete,
          [ :string, :pool ],
          :error
      attach_function :filesystem
          :svn_repos_fs,
          [ :repo ],
          :filesystem

      # filesystem functions
      attach_function :revision_root,
          :svn_fs_revision_root,
          [ :out_pointer, :filesystem, :revnum, :pool ],
          :error
      attach_function :transaction_root,
          :svn_fs_txn_root,
          [ :out_pointer, :pointer, :pool ],
          :error
      attach_function :close_root,
          :svn_fs_close_root,
          [ :pointer ],
          :void
    end

  end

end
