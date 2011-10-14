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

      # lifecycle functions
      attach_function :close_root,
          :svn_fs_close_root,
          [ :root ],
          :void

      # node metadata
      attach_function :is_dir,
          :svn_fs_is_dir,
          [ :out_pointer, :root, :string, :pool ],
          :error
      attach_function :is_file,
          :svn_fs_is_file,
          [ :out_pointer, :root, :string, :pool ],
          :error
      attach_function :created_rev,
          :svn_fs_node_created_rev,
          [ :out_pointer, :root, :string, :pool ],
          :error
      attach_function :created_path,
          :svn_fs_node_created_path,
          [ :out_pointer, :root, :string, :pool ],
          :error

      # props
      attach_function :get_prop,
          :svn_fs_node_prop,
          [ :out_pointer, :root, :string, :string, :pool ],
          :error

      # files
      attach_function :get_size,
          :svn_fs_file_length,
          [ :out_pointer, :root, :string, :pool ],
          :error
      attach_function :get_content,
          :svn_fs_file_contents,
          [ :out_pointer, :root, :string, :pool ],
          :error
    end

    def pool
      @pool ||= Svn::RootPool
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

    bind :file?, :to => :is_file,
        :returning => :int,
        :before_return => test_c_true,
        :validate => Error.return_check,
        &add_pool

    bind :get_size,
        :returning => :int64,
        :validate => Error.return_check,
        &add_pool

    bind :get_content,
        :returning => Stream,
        :before_return => :to_string_io,
        :validate => Error.return_check,
        &add_pool

    bind :created_rev,
        :returning => :long,
        :validate => Error.return_check,
        &add_pool

    bind :created_path,
        :returning => CountedString.by_ref,
        :validate => Error.return_check,
        &add_pool

    bind :get_prop,
        :returning => CountedString.by_ref,
        :before_return => :to_s,
        :validate => Error.return_check,
        &add_pool

  end

end
