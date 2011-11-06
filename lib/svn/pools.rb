require 'rubygems'
require 'ffi'

module Svn #:nodoc:

  # APR memory pool
  class Pool < FFI::AutoPointer

    class << self
      # create a new pool in +parent+.  if +parent+ is nil, the allocate a root pool.
      def create( parent=nil )
        out = FFI::MemoryPointer.new( :pointer )
        C.create( out, parent, C::RaiseOutOfMemory, nil )
        return new( out.read_pointer )
      end

      # free and release a pool
      def release( ptr )
        C.destroy( ptr )
      end
    end

    module C
      extend FFI::Library
      ffi_lib 'libapr-1.so.0'

      typedef :int, :apr_status
      typedef Pool, :pool

      callback :abort_function, [:apr_status], :int

      # life-cycle methods
      attach_function :initialize, :apr_initialize, [], :apr_status

      attach_function :create,
          :apr_pool_create_ex,
          [:pointer, :pool, :abort_function, :pointer],
          :apr_status

      attach_function :clear, :apr_pool_clear, [:pool], :void

      attach_function :destroy, :apr_pool_destroy, [:pool], :void

      # instance methods
      # apr_pool_cleanup_register
      # apr_pool_userdata_set
      # apr_pool_userdata_get

      RaiseOutOfMemory = FFI::Function.new( :int, [:int] ) do |status|
        raise NoMemoryError.new('Could not allocate new pool')
      end

      initialize
    end

    # use the C module for all bound methods
    bind_to C

    # clear all allocated memory in the pool so it can be reused
    bind :clear

  end

  # create the root pool that will be the default pool
  RootPool = Pool.create

end
