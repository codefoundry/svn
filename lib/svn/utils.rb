require 'rubygems'
require 'ffi'

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

    # a generic factory class for use with FFI data types that adds default
    # arguments to constructor calls
    #
    #  # when NativeHash is created, the args are [ptr, :string, :string]
    #  bind :get_hash, :returning => NativeHash.factory( :string, :string )
    class Factory

      # factories also work as DataConverters so they can be used with FFI
      include FFI::DataConverter

      def initialize( klass, *args )
        @klass = klass
        @added_args = args
      end

      def new( *args )
        @klass.new( *args, *@added_args )
      end

      def from_native( ptr, ctx )
        @klass.new( ptr, *@added_args )
      end

      def native_type
        @klass.native_type
      end

      def real_class
        @klass
      end

      def size
        @klass.size
      end
    end

    # returns the *contents* of the pointer as type
    #
    # for example:
    #  # void get_string( char **p ):
    #  get_string( out_ptr ); content_for( out_ptr, :string )
    #
    #  # void get_hash( hash_t **p ):
    #  class Hash < FFI::AutoPointer; end
    #  get_hash( out_ptr ); content_for( out_ptr, Hash )
    #
    # if the type is a FFI::Pointer, this will try to instantiate it; to avoid
    # instantiation, pass :pointer as the type
    def content_from( pointer, type, len=nil )
      return if pointer.nil?
      if type.is_a? Array
        type.inject( pointer ) do |ptr, subtype|
          content_for( ptr, subtype, len )
        end
      elsif type.is_a? Factory
        type.new( pointer.read_pointer ) unless pointer.null?
      elsif type.is_a?( Class ) && type.ancestors.include?( FFI::Pointer )
        type.new( pointer.read_pointer ) unless pointer.null?
      elsif type.is_a?( FFI::Type::Mapped )
        type.from_native( pointer.read_pointer, nil ) unless pointer.null?
      elsif type == :string
        pointer.read_pointer.read_string(
            ( len == -1 ) ? nil : len
          ) unless pointer.null?
      else
        pointer.send( :"read_#{type}" )
      end
    end

    # returns the the pointer's value as type
    #
    # for example:
    #  # char *get_string( void ):
    #  ptr = get_string()
    #  str = content_for( ptr, :string )
    #
    #  # hash *get_hash( void ):
    #  class Hash < FFI::AutoPointer; end
    #  ptr = get_hash( out_ptr )
    #  hash = content_for( out_ptr, Hash )
    def content_for( pointer, type, len=nil )
      return if pointer.nil?
      if type.is_a? Array
        type.inject( pointer ) do |ptr, subtype|
          content_for( ptr, subtype, len )
        end
      elsif type.is_a? Factory
        type.new( pointer ) unless pointer.null?
      elsif type.is_a?( Class ) && type.ancestors.include?( FFI::Pointer )
        type.new( pointer ) unless pointer.null?
      elsif type.is_a?( FFI::Type::Mapped )
        type.from_native( pointer, nil ) unless pointer.null?
      elsif type == :string
        # if len is nil or -1, use it for reading instead of counting on it to
        # be null-terminated
        pointer.read_string( ( len == -1 ) ? nil : len ) unless pointer.null?
      else
        pointer.send( :"read_#{type}" ) unless pointer.null?
      end
    end

    def pointer_for( value, type )
      if type.is_a? Array
        type.reverse.inject( value ) do |val, subtype|
          pointer_for( val, subtype )
        end
      elsif type.is_a? Factory
        pointer_for( value, type.real_class )
      elsif type.is_a?( Class ) && type.ancestors.include?( FFI::Pointer )
        # use val directly
        value
      elsif type.is_a?( FFI::Type::Mapped )
        # mapped types are really pointers to structs; they are read
        # differently, but they should still be pointers we can use directly
        value
      elsif type == :string
        # use from_string even if it isn't necessary to null-terminate
        FFI::MemoryPointer.from_string( value )
      else
        # it must be a FFI type, use a new MemoryPointer
        ptr = FFI::MemoryPointer.new( type )
        ptr.send( :"write_#{type}", value )
        ptr
      end
    end

    # this module contains extensions for classes that inherit from FFI::Struct
    # and FFI::AutoPointer to make binding instance methods to C methods more
    # concise
    module Extensions

      # convenience method that returns a Factory instance for self with the
      # given args
      #
      # the following are equivalent:
      #  NativeHash.factory( :string, :string )
      #
      #  Factory( NativeHash, :string, :string )
      def factory( *args )
        Factory.new( self, *args )
      end

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
          return_ptrs = return_types.map { |type|
            FFI::MemoryPointer.new( type )
          }

          # create the argument list for the function
          call_args = return_ptrs.dup
          call_args << self
          call_args += args

          return_val = nil # keep it in scope
          if block
            # call the method with the arguments after re-arranging via block
            return_val = meth.call( *instance_exec( *call_args, &block ) )
          else
            # call the method with the standard argument order
            return_val = meth.call( *call_args )
          end

          # call the return check, if present
          instance_exec( return_val, &validation ) if validation

          # if there are return types (out pointers), read the values out of
          # the pointers and replace the return_val
          unless return_types.empty?
            return_val = return_ptrs.zip( return_types ).map do |ptr, type|
              Utils.content_from( ptr, type )
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
    FFI::Struct.extend Extensions
    FFI::AutoPointer.extend Extensions

  end

end
