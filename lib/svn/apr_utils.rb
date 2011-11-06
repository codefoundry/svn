require 'rubygems'
require 'ffi'

module Svn #:nodoc:

  class AprHash < FFI::AutoPointer

    # when used as key length, indicates that string length should be used
    HASH_KEY_STRING = -1

    include Enumerable

    attr_accessor :keys_null_terminated
    alias_method :keys_null_terminated?, :keys_null_terminated

    def initialize( ptr, key_type, val_type, keys_null_terminated=true)
      super( ptr )
      @key_type = key_type
      @val_type = val_type
      @pointers = []
      @keys_null_terminated = keys_null_terminated
    end

    class << self
      # creates a new apr_hash_t that contains +contents+, if given
      def create( key_type, val_type, pool=RootPool )
        ptr = C.create( pool )
        new( ptr, key_type, val_type )
      end

      def create_from( rb_hash, key_type, val_type, pool=RootPool )
        create( key_type, val_type, pool ).copy_from( rb_hash )
      end

      def release( ptr )
        # memory will be released with the allocation pool
      end
    end

    module C
      extend FFI::Library
      ffi_lib 'libapr-1.so.0'

      typedef :pointer, :index
      typedef :pointer, :out_pointer
      typedef :long, :apr_ssize
      typedef Pool, :pool
      typedef AprHash, :hash

      # lifecycle functions
      # returns a :pointer instead of a :hash because AprHash#create needs to
      # add extra args to the ruby instantiation
      attach_function :create,
          :apr_hash_make,
          [ :pool ],
          :pointer

      # pool accessor -- returns a Pointer instead of a Pool because Pool
      # objects will destroy the pool when they are garbage collected. If the
      # pool was created in SVN, we should never destroy it and if the pool was
      # created elsewhere, then we should let the original instance destroy it.
      # This means that the function here should not actually return a Pool.
      attach_function :pool,
          :apr_hash_pool_get,
          [ :hash ],
          :pointer

      # size
      attach_function :count,
          :apr_hash_count,
          [ :hash ],
          :uint

      # getter/setter methods
      attach_function :get,
          :apr_hash_get,
          #  hash   key       klen
          [ :hash, :pointer, :apr_ssize ],
          :pointer
      attach_function :set,
          :apr_hash_set,
          #  hash   key       klen  val (NULL = delete entry)
          [ :hash, :pointer, :apr_ssize, :pointer ],
          :void

      # iteration functions
      attach_function :first,
          :apr_hash_first,
          [ :pool, :hash ],
          :index
      attach_function :next,
          :apr_hash_next,
          [ :index ],
          :index
      attach_function :this,
          :apr_hash_this,
          [ :index, :out_pointer, :out_pointer, :out_pointer ],
          :void
    end

    # use the above C module for the source of bound functions
    bind_to C

    # bound method definitions
    bind :size, :to => :count

    # because pool returns a Pointer and not a Pool as is expected, make it
    # private so others can't use it.
    bind :pool
    private :pool

    def each_pair
      # outgoing pointers for keys and values
      key_ptr = FFI::MemoryPointer.new( :pointer )
      # apr_ssize_t => ssize_t => platform-specific long
      len_ptr = FFI::MemoryPointer.new( :long )
      val_ptr = FFI::MemoryPointer.new( :pointer )

      # initialize a hash index to the first entry
      iter = C.first( pool, self )

      while !iter.null?
        # get the key, key length, and val
        C.this( iter, key_ptr, len_ptr, val_ptr )

        # read the key
        key_len = len_ptr.read_long
        key = Utils.content_for( key_ptr.read_pointer, @key_type, key_len )

        # yield the key and value
        yield key, Utils.content_for( val_ptr.read_pointer, @val_type ) if block_given?

        # advance to the next iteration
        iter = C.next( iter )
      end
    end

    def []( key )
      val = nil # keep val in scope

      if key.is_a?( String ) && keys_null_terminated?
        val = C.get( self, key, HASH_KEY_STRING )
      elsif key.respond_to? :size
        val = C.get( self, key, key.size )
      elsif key.respond_to? :length
        val = C.get( self, key, key.length )
      else
        raise ArgumentError, "Invalid key #{key}: cannot determine length"
      end

      Utils.content_for( val, @val_type )
    end

    def []=( key, val )
      val_ptr = Utils.pointer_for( val, @val_type )

      # because the pointers passed in are referenced in native code, keep
      # track of the pointers so they aren't garbage collected until this hash
      # is destroyed
      @pointers << val_ptr

      if key.is_a?( String ) && keys_null_terminated?
        C.set( self, key, HASH_KEY_STRING, val_ptr )
      elsif key.respond_to? :size
        C.set( self, key, key.size, val_ptr )
      elsif key.respond_to? :length
        C.set( self, key, key.length, val_ptr )
      else
        raise ArgumentError, "Invalid key #{key}: cannot determine length"
      end

      val
    end

    def copy_from( rb_hash )
      rb_hash.each_pair do |key, val|
        self[ key ] = val
      end

      self
    end

    def to_h
      rb_hash = {}
      each_pair do |key, val|
        rb_hash[ key ] = val
      end
      rb_hash
    end

  end

  class AprArray < FFI::AutoPointer

    include Enumerable

    def initialize( ptr, type )
      super( ptr )
      @type = type
      @pointers = []
    end

    class << self
      # creates a new AprArray of +nelts+ elements of +type+; allocation is done
      # in +pool+, which defaults to Svn::RootPool
      def create( type, nelts, pool=RootPool )
        ptr = C.create( pool, nelts, FFI::Pointer.size )
        new( ptr, type )
      end

      def create_from( rb_arr, type, pool=RootPool )
        create( type, rb_arr.size ).copy_from( rb_arr )
      end

      def release
        # memory will be released with the allocation pool
      end
    end

    module C
      extend FFI::Library
      ffi_lib 'libapr-1.so.0'

      typedef :pointer, :index
      typedef :pointer, :out_pointer
      typedef :long, :apr_ssize
      typedef Pool, :pool
      typedef AprArray, :array

      # allocation
      # returns a :pointer instead of a :array because AprArray#create needs to
      # add extra args to the ruby instantiation
      attach_function :create,
          :apr_array_make,
          [ :pool, :int, :int ],
          :pointer

      # empty?
      attach_function :is_empty,
          :apr_is_empty_array,
          [ :array ],
          :int

      # modifier methods
      attach_function :push,
          :apr_array_push,
          [ :array ],
          :pointer

      attach_function :pop,
          :apr_array_pop,
          [ :array ],
          :pointer
    end

    # helper procs for method binding
    test_c_true = Proc.new { |i| i == 1 }

    # use the above C module for the source of bound functions
    bind_to C

    # bound method definitions
    bind :empty?, :to => :is_empty,
        :before_return => test_c_true

    def push( el )
      # turn element into a pointer
      ptr = Utils.pointer_for( el, @type )
      # get the array element location and write ptr there
      location = C.push( self )
      location.write_pointer( ptr )

      # because the pointers passed in are referenced in native code, keep
      # track of the pointers so they aren't garbage collected until this hash
      # is destroyed
      @pointers << ptr

      el
    end
    alias_method :add, :push
    alias_method :<<, :push

    def copy_from( arr )
      arr.each do |el|
        self << el
      end
      self
    end

    def pop
      location = C.pop( self )
      Utils.content_for( location.read_pointer, @type )
    end

# these are commented out because they don't work. it doesn't look like APR
# array accesses happen this way.
#    def []( num )
#      num = num.to_i
#      Utils.content_for( get_pointer( num * FFI::Pointer.size ), @type )
#    end
#
#    def []=( num, val )
#      num = num.to_i
#
#      ptr = Utils.pointer_for( val, @type )
#      put_pointer( num * FFI::Pointer.size, ptr )
#
#      val
#    end

  end

end
