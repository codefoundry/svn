require 'stringio'
require 'rubygems'
require 'ffi'

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

      typedef :pointer, :in_out_len
      typedef CError.by_ref, :error
      typedef Pool, :pool
      typedef Stream, :stream
      typedef :size_t, :apr_size

      callback :read_function, [:pointer, :pointer, :pointer], :error
      callback :write_function, [:pointer, :string, :pointer], :error

      # lifecycle functions
      attach_function :create,
          :svn_stream_create,
          [:pointer, :pool], :pointer
      attach_function :set_read,
          :svn_stream_set_read,
          [:stream, :read_function], :void
      attach_function :set_write,
          :svn_stream_set_write,
          [:stream, :write_function], :void
      attach_function :close,
          :svn_stream_close,
          [:stream], :error

      # note: the SVN docs say that short reads indicate the end of the stream
      # and short writes indicate an error.  this means that we cannot use
      # read_nonblock and write_nonblock, since they do not guarantee anything
      # will happen.

      ReadFromIO = FFI::Function.new(
          :pointer, [:pointer, :pointer, :pointer]
        ) do |io_ptr, out_buffer, in_out_len|

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

      WriteToIO = FFI::Function.new(
          :pointer, [:pointer, :string, :pointer]
        ) do |io_ptr, in_string, in_out_len|

        # read the size of in_string and unwrap the io object
        bytes_to_write = in_out_len.read_int
        io = Svn::Utils.unwrap(io_ptr)

        # should we check that in_string isn't longer than in_out_len?
        bytes_written = io.write( in_string )

        # write the actual number of bytes written to io
        in_out_len.write_int( bytes_written )

        nil # return no error
      end

      # accessor functions
      attach_function :read,
          :svn_stream_read,
          [ :stream, :buffer_out, :in_out_len ],
          :error
    end

    def read( size=8192 )
      # setup the pointers
      @in_out_len ||= FFI::MemoryPointer.new( :size_t )
      @in_out_len.write_ulong( size )

      # make sure a buffer for reading exists and save it for reuse
      if @read_buf.nil? or @read_buf.size < size
        @read_buf = FFI::Buffer.alloc_out( size )
      end

      # call read to fill the buffer
      Error.check_and_raise(
          C.read( self, @read_buf, @in_out_len )
        )

      @read_buf.read_bytes( @in_out_len.read_ulong )
    end

    # reads the stream contents into a String object
    def read_all
      content = String.new
      while bytes = read and !bytes.empty?
        content << bytes
      end
      content
    end
    alias_method :to_s, :read_all

    # reads the entire stream and creates a CountedString from the contents
    #
    # Note that this function copies the entire stream into Ruby memory and
    # then copies it again into C memory. There is probably a more efficient
    # way to do this, by allocating a big string and re-allocing when the size
    # required overruns that memory
    def to_counted_string
      CountedString.from_string( read_all )
    end

    # reads the stream contents into a StringIO object
    def to_string_io
      content = StringIO.new
      while bytes = read and !bytes.empty?
        content.write( bytes )
      end
      content.rewind
      content
    end

  end

end
