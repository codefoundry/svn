require 'rubygems'
require 'ffi'

require 'svn/utils'

module Svn
  
  class Stream < FFI::AutoPointer

    class << self
      # Wraps an IO object to be used as a subversion stream
      def wrap_io( io, pool=RootPool )
        stream = new( C.create( Svn::Utils.wrap(io), pool ) )
        C.set_write( stream, C::WriteToIO )
        C.set_read( stream, C::ReadFromIO )
        return stream
      end

      def release( ptr )
        Error.check_and_raise(
            C.close( ptr )
          )
      end
    end

    module C
      extend FFI::Library
      ffi_lib 'libsvn_subr-1.so.1'

      typedef CError.by_ref, :error
      typedef Pool, :pool

      callback :read_function, [:pointer, :pointer, :pointer], :error
      callback :write_function, [:pointer, :string, :pointer], :error

      # lifecycle methods
      attach_function :create, :svn_stream_create, [:pointer, :pool], :pointer
      attach_function :set_read, :svn_stream_set_read, [:pointer, :read_function], :void
      attach_function :set_write, :svn_stream_set_write, [:pointer, :write_function], :void
      attach_function :close, :svn_stream_close, [:pointer], :error

      # note: the SVN docs say that short reads indicate the end of the stream
      # and short writes indicate an error.  this means that we cannot use
      # read_nonblock and write_nonblock, since they do not guarantee anything
      # will happen.

      ReadFromIO = FFI::Function.new( :pointer, [:pointer, :pointer, :pointer] ) do |io_ptr, out_buffer, in_out_len|
        # read the number of bytes requested and unwrap the io object
        bytes_to_read = in_out_len.read_int
        io = Svn::Utils.unwrap(io_ptr)

        # read the bytes from IO and write them to the pointer object
        bytes_read = io.read( bytes_to_read )
        out_buffer.write_string( bytes_read )

        # write the number of bytes read from io
        in_out_len.write_int( bytes_read.length )

        nil # return no error
      end

      WriteToIO = FFI::Function.new( :pointer, [:pointer, :string, :pointer] ) do |io_ptr, in_string, in_out_len|
        # read the size of in_string and unwrap the io object
        bytes_to_write = in_out_len.read_int
        io = Svn::Utils.unwrap(io_ptr)

        # should we check that in_string isn't longer than bytes_to_write?
        bytes_written = io.write( in_string )

        # write the actual number of bytes written to io
        in_out_len.write_int( bytes_written )

        nil # return no error
      end
    end
  end

end
