require 'rubygems'
require 'ffi'

module Svn #:nodoc:

  # a struct for interacting with svn_string_t values
  class CountedStringStruct < FFI::Struct

    layout(
        # because the data may not be NULL-terminated, treat it as a pointer
        # and always read the string contents with FFI::Pointer#read_string
        :data, :pointer,
        :length, :size_t
      )

    # returns a new ruby String with the CountedString's contents.
    def to_s
      self[:data].read_string( self[:length] )
    end

    def inspect
      to_s.inspect
    end

  end

  # the svn_string_t pointer type, which is the one used externally
  CountedString = CountedStringStruct.by_ref

  def CountedString.from_string( content )
    return content if content.is_a? CountedStringStruct
    cstr = CountedStringStruct.new
    cstr[:data] = FFI::MemoryPointer.from_string( content )
    cstr[:length] = content.size
    cstr
  end

end
