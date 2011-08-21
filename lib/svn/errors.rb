require 'rubygems'
require 'ffi'

module Svn

  class Error < RuntimeError

    # checks error and raises an exception for error if necessary
    def self.check_and_raise( err )
      return if err.null?
      raise Error.new( err )
    end

    attr_reader :c_error

    def initialize( c_error )
      @message = c_error[:message]
      @c_error = c_error
    end

  end

  class CError < FFI::Struct
    layout(
        :apr_error, :int,
        :message, :string,
        :child, :pointer,
        :pool, :pointer,
        :filename, :string,
        :line, :long
      )

    module C
      extend FFI::Library
      # error functions and ffi_lib entry
    end

  end

end
