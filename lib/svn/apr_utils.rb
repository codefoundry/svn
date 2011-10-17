require 'rubygems'
require 'ffi'

module Svn #:nodoc:

  class AprHash < FFI::AutoPointer

    # when used as key length, indicates that string length should be used
    HASH_KEY_STRING = -1

    include Enumerable

    attr_reader :pool

    def initialize( ptr, pool=RootPool )
      super( ptr )
      @pool = pool
    end

    class << self
      # creates a new apr_hash_t that contains +contents+, if given
      def create( contents={} )
        result = new
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
        C.this( iter, key_ptr, len_ptr, val_ptr )
        key = key_ptr.read_pointer.read_string( len_ptr.read_long )
        yield key, val_ptr.read_pointer if block_given?
        iter = C.next( iter )
      end
    end

    def []( key )
      # TODO: how should this be handled? detect the type of key and set klen
      # accordingly? This may require translation between C and ruby
      #
      # maybe key.class.size should be passed when the key is not a String?
      raise RuntimeError, 'AprHash keys must be strings' unless String === key
      C.get( self, key, HASH_KEY_STRING )
    end

    def []=( key, val )
      raise RuntimeError, 'AprHash keys must be strings' unless String === key
      C.set( self, key, HASH_KEY_STRING, val )
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
