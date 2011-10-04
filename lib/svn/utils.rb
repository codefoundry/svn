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

    # this module contains extensions for classes that inherit from FFI::Struct
    # and FFI::AutoPointer to make binding instance methods to C methods more
    # concise
    module Extensions

      module_function

      # sets the module that will be used for all bound methods
      def bind_to( target )
        @@target = target
      end

      def bind( sym, options={}, &block )
        # look up the method in the target module
        meth = @@target.method( sym )

        # create a new method
        if block_given?
          # blocks are used to re-arrange arguments
          define_method( sym ) do |*args|
            meth.call( *block.call( self, *args ) )
          end
        else
          define_method( sym ) do |*args|
            meth.call( self, *args )
          end
        end
      end

    end

    # extend FFI objects with the new helper methods
    #FFI::Struct.extend Extensions
    FFI::AutoPointer.extend Extensions

  end

end
