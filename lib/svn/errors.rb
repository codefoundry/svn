require 'rubygems'
require 'ffi'

module Svn

  class Error < RuntimeError

    class << self

      ERROR_CLASSES = {}

      # used to turn generic messages for unknown errors into class names
      # e.g., "Repository creation failed" => 'RepositoryCreationFailedError'
      def class_name_for( message )
        message.split(/\s+/).each(&:capitalize!).join + 'Error'
      end

      def specific_error_class( c_error )
        # if an error class is already set, return it. otherwise, create a new
        # one from the error's generic message
        (
            get( c_error.code ) ||
            add( c_error.code, class_name_for( c_error.generic_message ) )
          )
      end

      def get( code )
        ERROR_CLASSES[code]
      end

      def add( code, class_or_name )
        klass = nil # keep in scope

        if class_or_name.is_a? Class
          klass = class_or_name
        else
          name = class_or_name
          begin
            # fetch an existing error class and save it for the error code
            klass = Svn.const_get( name )
          rescue NameError => err
            # create the error class and return it
            $stderr.puts "Creating #{name} for #{code}" if $debug_svn_errors
            klass = Svn.const_set( name, Class.new( Svn::Error ) )
          end
        end

        ERROR_CLASSES[code] = klass
      end

      # checks error and raises an exception for error if necessary
      def check_and_raise( err_ptr )
        return if err_ptr.null?
        raise specific_error_class( err_ptr ).new( err_ptr.message )
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

  # create sensible names for known error classes
  Error.add( 2, :PathNotFoundError )
  Error.add( 160006, :InvalidRevisionError )
  Error.add( 165002, ArgumentError )
  Error.add( 200011, :DirectoryNotEmptyError )

  class CError < FFI::ManagedStruct
    layout(
        :error_code, :int,
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
      typedef :int, :error_code

      attach_function :best_message,
          :svn_err_best_message,
          [ :error, :buffer_inout, :size ],
          :string

      attach_function :root_cause,
          :svn_error_root_cause,
          [ :error ],
          :error

      attach_function :generic_message,
          :svn_strerror,
          [ :error_code, :buffer_inout, :size ],
          :string

      attach_function :clear,
          :svn_error_clear,
          [ :error ],
          :void
    end

    copy_msg = Proc.new { |msg| msg.dup if msg }

    bind_to C

    MSG_BUFFER = FFI::MemoryPointer.new(1024)
    # returns the error's specific message, if present, and the code's generic
    # message otherwise
    bind(
        :best_message,
        :before_return => copy_msg
      ) { |this| [this, MSG_BUFFER, 1024] }

    # returns the most specific error struct from this error chain
    bind :root_cause

    # returns the "generic" message for the error code
    bind(
        :generic_message,
        :before_return => copy_msg
      ) { |this| [ this[:error_code], MSG_BUFFER, 1024 ] }

    # returns the most specific error message from this error chain
    def cause_message
      root_cause.best_message
    end

    # returns a combined message if there are children, or the best otherwise
    def message
      if self[:child].null?
        best_message
      else
        "#{best_message}: #{cause_message}"
      end
    end

    def code
      self[:error_code]
    end

  end

end
