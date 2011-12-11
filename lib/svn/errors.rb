require 'rubygems'
require 'ffi'

module Svn

  class Error < RuntimeError

    class << self

      # checks error and raises an exception for error if necessary
      def check_and_raise( err )
        return if err.null?
        raise Error.new( err )
      end

      # returns a proc that calls check_and_raise
      def return_check
        @@return_check ||= Proc.new { |ptr| Error.check_and_raise( ptr ) }
      end

    end

    attr_reader :c_error

    def initialize( message_or_c_error )
      if message_or_c_error.is_a? CError
        super( message_or_c_error.best_message )
        @c_error = message_or_c_error
      else
        super( message_or_c_error )
      end
    end

  end

  class CError < FFI::ManagedStruct
    layout(
        :apr_error, :int,
        :message, :string,
        :child, :pointer,
        :pool, :pointer,
        :filename, :string,
        :line, :long
      )

    class << self
      def release( ptr )
        C.clear( ptr )
      end
    end

    # returns the most accurate message for an error
    def best_message
      # create a buffer, which may be used to hold the best message
      buf = FFI::MemoryPointer.new( 1024 )
      msg = C.best_message( self, buf, 1024 )

      # return a duplicate of msg, since it may be stored in the buffer
      # allocated above
      msg.dup
    end

    module C
      extend FFI::Library
      ffi_lib 'libsvn_subr-1.so.1'

      typedef CError.by_ref, :error
      typedef :int, :size

      attach_function :best_message,
          :svn_err_best_message,
          [ :error, :buffer_inout, :size ],
          :string

      attach_function :clear,
          :svn_error_clear,
          [ :error ],
          :void
    end

  end

end
