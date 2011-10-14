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

      # sets the module that will be used for all bound methods, until bind_to
      # is called again
      def bind_to( target )
        @@target = target
      end

      # binds a method on the current target to self
      #
      # == arguments
      # +sym+ :: the method on the target (set by +bind_to+) to use
      # +options+ :: a Hash of optional method aliases or returned arguments
      #
      # == options
      # +:as+ :: method name to use for the bound method
      # +:to+ :: function name to use from the target object
      # +:returning+ :: an array of types for out parameters
      # +:validate+ :: a validation to call on the bound method's return value
      # +:before_return+ :: a function to call on the return value
      #
      # TODO: call to_proc on symbols that should be procs
      def bind( sym, options={}, &block )
        # look up the method in the target module
        meth_name = ( options[:to] || sym ).to_sym
        # get a method obj from the target receiver so that if @@target is
        # changed by another call to :bind_to, the method/target will not be
        # changed (and broken)
        meth = @@target.method( meth_name )
        name = ( options[:as] || sym ).to_sym

        # get the return types as an Array and save a copy
        single_return = !options[:returning].is_a?( Array )
        return_types = Array( options[:returning] ).dup

        # get the C function validation
        validation = options[:validate]

        # get the before_return filter
        before_return = options[:before_return] || lambda { |x| x }

        # create a new method; blocks are used to re-arrange arguments
        define_method( name ) do |*args|
          # create new pointers for the specified out arguments
          return_ptrs = return_types.map { |type| FFI::MemoryPointer.new( type ) }

          return_val = nil # keep it in scope
          if block
            # call the method with the arguments after re-arranging via block
            return_val = meth.call( *instance_exec(
                *return_ptrs, self, *args, &block
              ) )
          else
            # call the method with the standard argument order
            return_val = meth.call( *return_ptrs, self, *args )
          end

          # call the return check, if present
          instance_exec( return_val, &validation ) if validation

          # if there are return types (out pointers), read the values out of
          # the pointers and replace the return_val
          unless return_types.empty?
            return_val = return_ptrs.zip( return_types ).map do |ptr, type|
              # if the type is a FFI::Pointer, then try to instantiate it; to
              # avoid instantiation, pass :pointer as the type
              if type.is_a?( Class ) && type.ancestors.include?( FFI::Pointer )
                type.new( ptr.read_pointer )
              else
                ptr.send( :"read_#{type}" )
              end
            end
            return_val = return_val.first if single_return
          end

          # run the before_return filter and return the value from it; if no
          # :before_return was in options, this will be the id function
          instance_exec( return_val, &before_return )
        end

      end

    end

    # extend FFI objects with the new helper methods
    #FFI::Struct.extend Extensions
    FFI::AutoPointer.extend Extensions

  end

end
