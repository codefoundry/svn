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
      #attach_function :set_prop,
      #    :svn_fs_node_change_prop,
      #    [ :root, :string, :string, :string, :pool ],
      #    :error

      # files
      attach_function :get_size,
          :svn_fs_file_length,
          [ :out_pointer, :root, :string, :pool ],
          :error
      attach_function :get_content,
          :svn_fs_file_length,
          [ :out_pointer, :root, :string, :pool ],
          :error
    end

    def pool
      @pool ||= Svn::RootPool
    end

    def dir?( path )
      out = FFI::Pointer.new( :int )
      C.is_dir( out, self, path, pool )
      out.read_int == 1
    end

    def file?( path )
      out = FFI::Pointer.new( :int )
      C.is_file( out, self, path, pool )
      out.read_int == 1
    end

    def created_rev( path )
      out = FFI::Pointer.new( :int )
      C.created_rev( out, self, path, pool )
      out.read_int
    end

    # TODO: how are out buffers used?
    #def created_path( path )
    #  out = FFI::OutBuffer.new
    #  C.created_rev( out, self, path, pool )
    #  out.read
    #end

    #bind_to C

    #bind :is_dir
    #bind :is_file


  end

end
