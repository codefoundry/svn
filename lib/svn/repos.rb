require 'rubygems'
require 'ffi'

module Svn #:nodoc:

  # A subverion repository object
  #
  # This represents both the repository and the filesystem
  class Repo < FFI::AutoPointer

    attr_reader :pool

    def initialize( ptr, pool )
      super( ptr )
      @pool = pool
    end

    class << self
      #--
      # several methods remove trailing separators; this is to avoid triggering
      # assertions in SVN libs
      #++
      def open( path, parent=RootPool )
        # get a new pool for all interactions with this repository
        pool = Pool.create( parent )

        # TODO: we may need to call find_root_path for this, if C.open expects
        # an exact repository root path
        out = FFI::MemoryPointer.new( :pointer )

        Error.check_and_raise(
            C.open( out, path.chomp(File::SEPARATOR), pool )
          )

        new( out.read_pointer, pool )
      end

      def create( path, parent=RootPool )
        # get a new pool for all interactions with this repository
        pool = Pool.create( parent )

        out = FFI::MemoryPointer.new( :pointer )

        Error.check_and_raise(
            C.create( out, path.chomp(File::SEPARATOR), nil, nil, nil, nil, pool )
          )

        new( out.read_pointer, pool )
      end

      def delete( path, pool=RootPool )
        Error.check_and_raise(
            C.delete( path.chomp(File::SEPARATOR), pool )
          )
      end

      # this release method does nothing because the repo will be released when
      # its pool is destroyed
      def release( ptr )
      end
    end

    # A filesystem object.  Repositories completely encapsulate the filesystem,
    # so it is unnecessary to use it directly.
    class FileSystem < FFI::AutoPointer
      class << self
        # this release method does nothing because the filesystem will be
        # released with its pool, which is associated with the repo that owns
        # the filesystem
        def release( ptr )
        end
      end
    end

    # returns the repository's filesystem
    #
    # this is for internal use because Repo objects should handle all fs
    # functionality
    def filesystem
      @fs ||= C.filesystem( self )
    end
    alias_method :fs, :filesystem

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

      # misc functions
      attach_function :find,
          :svn_repos_find_root_path,
          [ :string, :pool ],
          :string

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

    # use the above C module for the source of bound functions
    bind_to C

    # returns a Revision for rev +num+, or nil if the rev does not exist
    bind( :revision,
        :returning => :pointer,
        :before_return => Proc.new { |ptr|
            Revision.new( ptr, fs, pool ) unless ptr.null?
          },
        :validate => Error.return_check
        ) { |out, this, num| [ out, fs, num, pool ] }

  end

end
