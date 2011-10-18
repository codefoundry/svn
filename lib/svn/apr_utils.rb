require 'rubygems'
require 'ffi'

module Svn #:nodoc:

  class AprHash < FFI::AutoPointer

    # when used as key length, indicates that string length should be used
    HASH_KEY_STRING = -1

    include Enumerable

    attr_reader :pool

    def initialize( ptr, key_type, val_type, pool=RootPool )
      super( ptr )
      @key_type = key_type
      @val_type = val_type
      @pool = pool
      @pointers = []
    end

    class << self
      # creates a new apr_hash_t that contains +contents+, if given
      def create( key_type, val_type, contents={}, pool=RootPool )
        result = new( key_type, val_type, pool )
        contents.each_pair do |key, val|
          result[ key.to_s ] = val
        end
        result
      end

      def release( ptr )
        C.clear( ptr )
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

    bind_to C
    bind :size, :to => :count

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
        key = Utils.content_for( key_ptr, @key_type, key_len )

        # yield the key and value
        yield key, Utils.content_for( val_ptr, @val_type ) if block_given?

        # advance to the next iteration
        iter = C.next( iter )
      end
    end

    def []( key )
      val = nil # keep val in scope

      if key.is_a? String && keys_null_terminated?
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

      if key.is_a? String && keys_null_terminated?
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

    def to_h
      rb_hash = {}
      each_pair do |key, val|
        rb_hash[key] = val
      end
      rb_hash
    end

  end

  class AprArray < FFI::AutoPointer

    module C
      extend FFI::Library
      ffi_lib 'libapr-1.so.0'

    end

  end

end
