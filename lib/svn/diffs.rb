require 'rubygems'
require 'stringio'
require 'ffi'

module Svn #:nodoc:

  class Diff < FFI::AutoPointer

    class << self
      def diff( original_path, modified_path, options={}, pool=RootPool )
        options = FileOptions.from_hash( options ) if options.is_a? Hash

        out = FFI::MemoryPointer.new( :pointer )

        err = C.file_diff( out, original_path, modified_path, options, pool )

        Error.check_and_raise( err )

        d = new( out.read_pointer )
        d.original_path = original_path
        d.modified_path = modified_path
        d.options = options
        d.pool = pool

        return d
      end

      def release( ptr )
        # diff objects will probably need to keep track of the pool in which
        # they are allocated so they can be freed in that pool
      end
    end

    attr_accessor :original_path
    attr_accessor :modified_path
    attr_accessor :options
    attr_accessor :pool

    def changed?
      ( C.is_changed( self ) == 1 )
    end

    def conflicts?
      ( C.has_conflicts( self ) == 1 )
    end

    def unified(
        out_stream=nil, original_header=nil, modified_header=nil,
        path_strip=nil, encoding='utf-8'
      )
      out_stream ||= StringIO.new

      Error.check_and_raise( C.output_unified(
          Svn::Stream.wrap_io( out_stream ), self, original_path, modified_path,
          original_header, modified_header, encoding, path_strip,
          options[:show_c_function], pool
        ) )

      out_stream
    end

    class FileOptionsStruct < FFI::Struct
      layout(
          :ignore_whitespace, :int, # :whitespace,
          :ignore_eol_style, :int,
          :show_c_function, :int
        )

      def self.from_hash( hash )
        options = new
        hash.each_pair do |key, val|
          # add a check if key is in members?
          options[key] = val
        end
        options
      end
    end

    # create a mapped type for use elsewhere
    FileOptions = FileOptionsStruct.by_ref

    module C

      extend FFI::Library
      ffi_lib 'libsvn_diff-1.so.1'

      typedef Pool, :pool
      typedef CError.by_ref, :error
      typedef Stream, :stream
      typedef FileOptions, :file_options
      typedef Diff, :diff

      enum :whitespace, [
          :none,    # do not ignore whitespace
          :change,  # treat as a single char
          :all      # ignore all whitespace chars
        ]

      attach_function :file_diff,
          :svn_diff_file_diff_2,
          [:pointer, :string, :string, :file_options, :pool],
          :error
      attach_function :file_diff3,
          :svn_diff_file_diff3_2,
          [:pointer, :string, :string, :string, :file_options, :pool],
          :error
      attach_function :file_diff4,
          :svn_diff_file_diff4_2,
          [:pointer, :string, :string, :string, :string, :file_options, :pool],
          :error
      attach_function :output_unified,
          :svn_diff_file_output_unified3,
          [:stream, :diff, :string, :string, :string, :string, :string, :string, :int, :pool],
          :error
      attach_function :is_changed, :svn_diff_contains_diffs, [:diff], :int
      attach_function :has_conflicts, :svn_diff_contains_conflicts, [:diff], :int
    end

  end

end
