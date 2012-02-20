require 'rubygems'
require 'ffi'

module Svn

  class Error < RuntimeError

    class << self

      def specific_error_class( message )
        # turn the error message into a specific class name
        error_class = message.split(/\s+/).each(&:capitalize!).join + 'Error'
        begin
          # fetch an existing error class
          Svn.const_get( error_class )
        rescue NameError => err
          # create the error class and return it
          Svn.const_set( error_class, Class.new( Svn::Error ) )
        end
      end

      # checks error and raises an exception for error if necessary
      def check_and_raise( err_ptr )
        return if err_ptr.null?
        raise specific_error_class( err_ptr.best_message ).new( err_ptr )
      end

      # returns a proc that calls check_and_raise
      def return_check
        @@return_check ||= Proc.new { |ptr| Error.check_and_raise( ptr ) }
      end

    end

    attr_reader :c_error

    def initialize( message_or_c_error )
      if message_or_c_error.is_a? CError
        super( message_or_c_error.cause_message )
        @c_error = message_or_c_error
      else
        super( message_or_c_error )
      end
    end

  end

  # pre-create specific error classes
  [
      'RepositoryCreationFailedError'
    ].each do |name|
    const_set name, Class.new( Svn::Error )
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

    module C
      extend FFI::Library
      ffi_lib 'libsvn_subr-1.so.1'

      typedef CError.by_ref, :error
      typedef :int, :size

      attach_function :best_message,
          :svn_err_best_message,
          [ :error, :buffer_inout, :size ],
          :string

      attach_function :root_cause,
          :svn_error_root_cause,
          [ :error ],
          :error

      attach_function :clear,
          :svn_error_clear,
          [ :error ],
          :void
    end

    bind_to C

    MSG_BUFFER = FFI::MemoryPointer.new(1024)
    bind(
        :best_message,
        :before_return => Proc.new { |msg| msg.dup if msg }
      ) { |this| [this, MSG_BUFFER, 1024] }

    bind :root_cause

    def cause_message
      root_cause.best_message
    end

  end

end
