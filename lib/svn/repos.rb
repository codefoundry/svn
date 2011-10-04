require 'rubygems'
require 'ffi'

module Svn #:nodoc:

  # A subverion repository object
  #
  # This represents both the repository and the filesystem
  class Repo < FFI::AutoPointer

    attr_reader :pool

    def initialize( address, pool )
      @pool = pool
    end

    class << self
      def open( path, parent=RootPool )
        # get a new pool for all interactions with this repository
        pool = Pool.create( parent )

        # TODO: we may need to call find_root_path for this, if C.open expects
        # an exact repository root path
        out = FFI::MemoryPointer.new( :pointer )

        Error.check_and_raise(
            C.open( out, path, pool )
          )

        new( out.read_pointer, pool )
      end

      def create( path, parent=RootPool )
        # get a new pool for all interactions with this repository
        pool = Pool.create( parent )

        out = FFI::MemoryPointer.new( :pointer )

        Error.check_and_raise(
            C.create( out, path, nil, nil, nil, nil, pool )
          )

        new( out.read_pointer, pool )
      end

      def delete( path, pool=RootPool )
        Error.check_and_raise(
            C.delete( path, pool )
          )
      end

      # this release method does nothing because the repo will be released with
      # its pool, which is @pool
      def release( ptr )
      end
    end

    # A filesystem object.  Repositories completely encapsulate the filesystem,
    # so it is unnecessary to use it directly.
    class FileSystem < FFI::AutoPointer
      class << self
        # this release method does nothing because the filesystem will be
        # released with its pool, which is @pool on the repo that owns the fs
        def release( ptr )
        end
      end
    end

    # return the repository's filesystem
    def filesystem
      @fs ||= FileSystem.new( C.filesystem( self ) )
    end
    alias_method :fs, :filesystem

    def revision( num )
      out = FFI::Pointer.new( :pointer )
      C.revision( out, filesystem, num, pool )
      Revision.new( out.read_pointer )
    end

    module C
      extend FFI::Library
      ffi_lib 'libsvn_repos-1.so.1'

      typedef :pointer, :out_pointer
      typedef Pool, :pool
      typedef CError.by_ref, :error
      typedef FileSystem, :filesystem
      #typedef Properties, :hash # TODO
      typedef Revision, :revision
      #typedef Transaction, :transaction
      typedef Repo, :repo
      typedef :long, :revnum

      # repository functions
      attach_function :open,
          :svn_repos_open,
          [ :out_pointer, :string, :pool ],
          :error
      attach_function :create,
          :svn_repos_create,
          [ :out_pointer, :string, :pointer, :pointer, :pointer, :pointer, :pool ],
          :error
      attach_function :delete,
          :svn_repos_delete,
          [ :string, :pool ],
          :error

      # filesystem accessor
      attach_function :filesystem,
          :svn_repos_fs,
          [ :repo ],
          :filesystem

      # transaction (root) accessor, creation, and manipulation
      #attach_function :create_transaction,
      #    :svn_repos_fs_begin_txn_for_commit2,
      #    [ :out_pointer, :repo, :revnum, :hash, :pool ],
      #    :error
      #attach_function :commit_transaction,
      #    :svn_repos_fs_commit_txn,
      #    [ :out_pointer, :repo, :out_pointer, :transaction ],
      #    :error

      ffi_lib 'libsvn_fs-1.so.1'

      # revision (root) accessor
      attach_function :revision,
          :svn_fs_revision_root,
          [ :out_pointer, :filesystem, :revnum, :pool ],
          :error

      #attach_function :open_transaction,
      #    :svn_fs_begin_txn2,
      #    [ :out_pointer, :filesystem, :string, :pool ],
      #    :error
    end

  end

end
