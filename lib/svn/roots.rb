require 'rubygems'
require 'ffi'

module Svn #:nodoc:

  class Root < FFI::AutoPointer

    class << self
      def release( ptr )
        C.close_root( ptr )
      end
    end

    module C
      extend FFI::Library
      ffi_lib 'libsvn_fs-1.so.1'

      typedef :pointer, :out_pointer
      typedef Pool, :pool
      typedef CError.by_ref, :error
      typedef Root, :root
      typedef :string, :path
      typedef :string, :name

      # lifecycle functions
      attach_function :close_root,
          :svn_fs_close_root,
          [ :root ],
          :void

      # node metadata
      attach_function :is_dir,
          :svn_fs_is_dir,
          [ :out_pointer, :root, :path, :pool ],
          :error
      attach_function :is_file,
          :svn_fs_is_file,
          [ :out_pointer, :root, :path, :pool ],
          :error
      attach_function :created_rev,
          :svn_fs_node_created_rev,
          [ :out_pointer, :root, :path, :pool ],
          :error
      attach_function :created_path,
          :svn_fs_node_created_path,
          [ :out_pointer, :root, :path, :pool ],
          :error

      # props
      attach_function :node_prop,
          :svn_fs_node_prop,
          [ :out_pointer, :root, :path, :name, :pool ],
          :error
      attach_function :node_proplist,
          :svn_fs_node_proplist,
          [ :out_pointer, :root, :path, :pool ],
          :error

      # files
      attach_function :file_size,
          :svn_fs_file_length,
          [ :out_pointer, :root, :path, :pool ],
          :error
      attach_function :file_content,
          :svn_fs_file_contents,
          [ :out_pointer, :root, :path, :pool ],
          :error

      # dirs
      attach_function :dir_content,
          :svn_fs_dir_entries,
          [ :out_pointer, :root, :path, :pool ],
          :error

      # changes
      attach_function :changes,
          :svn_fs_paths_changed2,
          [ :out_pointer, :root, :pool ],
          :error
    end

    def pool
      @pool ||= RootPool
    end

    # helper procs for method binding
    test_c_true = Proc.new { |i| i == 1 }
    add_pool = Proc.new { |out, this, *args| [ out, this, *args, pool ] }

    # use the above C module for the source of bound functions
    bind_to C

    # bound method definitions
    bind :dir?, :to => :is_dir,
        :returning => :int,
        :before_return => test_c_true,
        :validate => Error.return_check,
        &add_pool

    bind :dir_content,
        :returning => AprHash.factory( :string, :pointer ),
        :before_return => Proc.new { |h| h.to_h.keys },
        :validate => Error.return_check,
        &add_pool

    bind :file?, :to => :is_file,
        :returning => :int,
        :before_return => test_c_true,
        :validate => Error.return_check,
        &add_pool

    bind :file_size,
        :returning => :int64,
        :validate => Error.return_check,
        &add_pool

    bind :file_content,
        :returning => Stream,
        :before_return => :to_string_io,
        :validate => Error.return_check,
        &add_pool

    bind :file_content_stream, :to => :file_content,
        :returning => Stream,
        :validate => Error.return_check,
        &add_pool

    bind :created_rev,
        :returning => :long,
        :validate => Error.return_check,
        &add_pool

    bind :created_path,
        :returning => :string,
        :validate => Error.return_check,
        &add_pool

    # returns the +path+'s property value for +name+
    bind :prop_for, :to => :node_prop,
        :returning => CountedString,
        :before_return => :to_s,
        :validate => Error.return_check,
        &add_pool

    # returns a hash of name to property values for +path+
    bind :props_for, :to => :node_proplist,
        :returning => AprHash.factory( :string, [:pointer, :string] ),
        :before_return => :to_h,
        :validate => Error.return_check,
        &add_pool

    # return the changes in this revision or transaction
    bind :changes,
        :returning => AprHash.factory( :string, ChangedPath ),
        :before_return => :to_h,
        :validate => Error.return_check,
        &add_pool

  end

end
