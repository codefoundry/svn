require 'rubygems'
require 'ffi'

module Svn #:nodoc:

  INVALID_REVNUM = -1

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
            C.create(
                out, # an out pointer to the newly created repository
                path.chomp(File::SEPARATOR), # path on disk
                nil, nil, # unused
                nil, nil, # configs are not implemeted
                pool # the pool to use for any allocations
              )
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

      # convenience pointers
      typedef :pointer, :out_pointer
      typedef :string, :path
      typedef :long, :revnum
      typedef :int, :bool

      # data types
      typedef Pool, :pool
      typedef AprHash, :hash
      typedef AprArray, :array
      typedef CError.by_ref, :error
      typedef FileSystem, :filesystem
      typedef Log::Entry, :log_entry
      typedef Root, :root
      typedef Revision, :revision
      #typedef Transaction, :transaction
      typedef Repo, :repo

      callback :history_function,
          [ :pointer, :path, :revnum, :pool ],
          :error

      CollectChanges = FFI::Function.new(
          :pointer, [ :pointer, :string, :long, :pointer ]
        ) do |data_ptr, path, rev, pool|
        arr = Utils.unwrap( data_ptr )
        arr << [ path, rev ]
        nil # no error
      end

      callback :authz_function,
          [ :out_pointer, :root, :path, :pointer, :pool ],
          :error

      callback :log_entry_function,
          [ :pointer, :log_entry, :pool ],
          :error

      CollectHistory = FFI::Function.new(
          :pointer, [ :pointer, :pointer, :pointer ]
        ) do |data_ptr, log_entry, pool|
        arr = Utils.unwrap( data_ptr )
        arr << Utils.content_for( log_entry, Log::Entry )
        nil # no error
      end

      # misc functions
      attach_function :find,
          :svn_repos_find_root_path,
          [ :path, :pool ],
          :string

      # repository functions
      attach_function :open,
          :svn_repos_open,
          [ :out_pointer, :path, :pool ],
          :error
      attach_function :create,
          :svn_repos_create,
          [ :out_pointer, :path,
            :pointer, :pointer, # both unused
            :hash, :hash,       # config, fs-config
            :pool ],
          :error
      attach_function :delete,
          :svn_repos_delete,
          [ :path, :pool ],
          :error

      # filesystem accessor
      attach_function :filesystem,
          :svn_repos_fs,
          [ :repo ],
          :filesystem

      # repository-level inspection
      attach_function :history,
          :svn_repos_history2,
          [ :filesystem, :path,
            :history_function, :pointer,  # history callback and data
            :authz_function, :pointer,    # authz callback and data
            :revnum, :revnum,             # start rev and end rev
            :bool, :pool ],               # cross copies?
          :error

      attach_function :logs,
          :svn_repos_get_logs4,
          [ :repo,
            :array, # file paths
            :revnum, :revnum, :int, # start rev, end rev, and limit
            :bool,                  # discover changed paths?
            :bool,                  # strict history? strict = no cross copies
            :bool,                  # include merged revisions?
            :array,                 # rev-prop names to get; NULL=all, []=none
            :authz_function, :pointer,      # authz callback and data
            :log_entry_function, :pointer,  # receiver callback and data
            :pool
            ],
          :error

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

      # youngest revision number accessor
      attach_function :youngest,
          :svn_fs_youngest_rev,
          [ :out_pointer, :filesystem, :pool ],
          :error

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

    use_fs_and_add_pool = Proc.new { |out, this, *args|
        [ out, fs, *args, pool ]
      }

    # use the above C module for the source of bound functions
    bind_to C

    # returns the number of the youngest revision in the repository
    bind :youngest,
        :returning => :long,
        :validate => Error.return_check,
        &use_fs_and_add_pool

    alias_method :latest, :youngest

    # returns a Revision for rev +num+ or raises Svn::Error if the revision
    # does not exist
    bind :revision,
        :returning => :pointer,
        :before_return => Proc.new { |ptr|
            Revision.new( ptr, fs, pool ) unless ptr.null?
          },
        :validate => Error.return_check,
        &use_fs_and_add_pool

    # returns an array of "interesting" revisions and paths for path
    #
    # for more detailed information, use +history+
    #
    # if a block is given, each [path, rev] pair will be yielded
    #
    # options:
    # +start_rev+ :: restricts revisions to newer than :start_rev
    # +end_rev+ :: restricts revisions to older than :end_rev
    # +cross_copies+ :: continue history at filesystem copies?
    def change_revs( path, options={}, &block )
      # ensure the options can be passed to C successfully
      start_rev = (options[:start_rev] || 0).to_i
      end_rev = (options[:end_rev] || youngest).to_i
      cross_copies = ( options[:cross_copies] ? 1 : 0 )

      # collect the change [path, rev] pairs
      changes = []
      Error.check_and_raise( C.history(
          fs, path,
          C::CollectChanges, Utils.wrap( changes ),
          nil, nil, start_rev, end_rev, cross_copies, pool
        ) )

      # if the caller supplied a block, use it
      changes.each( &block ) if block_given?

      changes
    end

    def history( paths, options={}, &block )
      # ensure the options can be passed to C successfully
      paths_c_arr = AprArray.create_from( Array( paths ), :string )
      start_rev = (options[:start_rev] || 0).to_i
      end_rev = (options[:end_rev] || youngest).to_i
      limit = (options[:limit] || 0).to_i # 0 => all entries
      discover_changed_paths = ( options[:include_changes] ? 1 : 0 )
      strict_history = ( options[:cross_copies] ? 0 : 1 )
      include_merged = ( options[:include_merged] ? 1 : 0 )
      rev_props = ( options[:include_props] ?
          AprArray.create_from( Array( options[:include_props] ) ) :
          nil
        )

      # collect the history entries
      history = []
      Error.check_and_raise( C.logs(
          self, paths_c_arr,
          start_rev, end_rev, limit,
          discover_changed_paths, strict_history, include_merged,
          rev_props, nil, nil,
          C::CollectHistory, Utils.wrap( history ),
          pool
        ) )

      # if the caller supplied a block, use it
      history.each( &block ) if block_given?

      history
    end

  end

end
