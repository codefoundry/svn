require 'rubygems'

module Svn #:nodoc:

  # Utility functions for working with FFI
  module Utils

    module_function

    # Returns a pointer to the object_id of +obj+
    def wrap( obj )
      ptr = FFI::MemoryPointer.new( :uint64 )
      ptr.write_uint64( obj.object_id )
      ptr
    end

    # Returns the object for the object_id stored in +ptr+
    def unwrap( ptr )
      ObjectSpace._id2ref( ptr.read_uint64 )
    end

  end

end
