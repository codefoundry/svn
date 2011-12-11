require 'rubygems'
require 'stringio'
require 'ffi'

module Svn #:nodoc:

  class Diff < FFI::AutoPointer

    class << self
      def string_diff( original, modified, options={}, pool=RootPool )
        options = FileOptions.from_hash( options ) if options.is_a? Hash
        original = CountedString.from_string( original )
        modified = CountedString.from_string( modified )

        out = FFI::MemoryPointer.new( Diff )

        Error.check_and_raise(
            C.string_diff( out, original, modified, options, pool )
          )

        d = new( out.read_pointer )

        return nil if d.null?

        d.type = :string
        d.original = original
        d.modified = modified
        d.options = options
        d.pool = pool

        return d
      end

      def file_diff( original_path, modified_path, options={}, pool=RootPool )
        options = FileOptions.from_hash( options ) if options.is_a? Hash

        out = FFI::MemoryPointer.new( Diff )

        Error.check_and_raise(
            C.file_diff( out, original_path, modified_path, options, pool )
          )

        d = new( out.read_pointer )

        return nil if d.null?

        d.type = :file
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

    attr_accessor :type
    attr_accessor :original
    attr_accessor :original_path
    attr_accessor :modified
    attr_accessor :modified_path
    attr_accessor :options
    attr_accessor :pool

    def changed?
      ( C.is_changed( self ) == 1 )
    end

    def conflicts?
      ( C.has_conflicts( self ) == 1 )
    end

    def unified( *args )
      # keep these in scope
      out_stream = nil
      options = nil
      pool = nil

      case args.size
      when 0
        # use all defaults
      when 1
        if args.first.is_a? Hash
          options = args.first
        elsif args.first.is_a? IO or args.first.is_a? StringIO
          out_stream = args.first
        elsif args.first.is_a? Pool
          pool = args.first
        end
      when 2, 3
        out_stream, options, pool = args
      else
        raise ArgumentError, "wrong number of arguments (#{args.size} for 3)"
      end

      # defaults
      out_stream ||= StringIO.new
      options ||= {}
      pool ||= RootPool

      # get common options
      encoding = options[:encoding] || 'utf-8'
      original_header = options[:original_header]
      modified_header = options[:modified_header]

      case type
      when :string
        with_diff_header = ( options[:with_diff_header] ? 1 : 0 )

        Error.check_and_raise( C.string_output_unified(
            Svn::Stream.wrap_io( out_stream ), self,
            original_header, modified_header, encoding,
            original, modified, pool
          ) )

      when :file
        path_strip = options[:path_strip]
        show_c_function = ( options[:show_c_function] ? 1 : 0 )

        Error.check_and_raise( C.file_output_unified(
            Svn::Stream.wrap_io( out_stream ), self,
            original_path, modified_path,
            original_header, modified_header, encoding, path_strip,
            show_c_function, pool
          ) )
      end

      out_stream.rewind if out_stream.is_a? StringIO

      out_stream
    end

    class FileOptionsStruct < FFI::Struct
      layout(
          :ignore_whitespace, :int, # :whitespace,
          :ignore_eol_style, :int,
          :show_c_function, :int
        )
    end

    # create a mapped type for use elsewhere
    FileOptions = FileOptionsStruct.by_ref

    def FileOptions.from_hash( hash )
      options = FileOptionsStruct.new
      hash.each_pair do |key, val|
        # add a check if key is in members?
        options[key] = val
      end
      options
    end

    module C

      extend FFI::Library
      ffi_lib 'libsvn_diff-1.so.1'

      typedef :pointer, :out_pointer
      typedef Pool, :pool
      typedef CError.by_ref, :error
      typedef Stream, :stream
      typedef FileOptions, :file_options
      typedef CountedString, :counted_string
      typedef Diff, :diff

      enum :whitespace, [
          :none,    # do not ignore whitespace
          :change,  # treat as a single char
          :all      # ignore all whitespace chars
        ]

      # diff functions
      attach_function :file_diff,
          :svn_diff_file_diff_2,
          [ :out_pointer, :string, :string, :file_options, :pool ],
          :error

      attach_function :string_diff,
          :svn_diff_mem_string_diff,
          [ :out_pointer, :counted_string, :counted_string, :file_options,
            :pool ],
          :error

      # diff inspection
      attach_function :is_changed, :svn_diff_contains_diffs, [:diff], :int
      attach_function :has_conflicts, :svn_diff_contains_conflicts, [:diff], :int

      # output functions
      attach_function :file_output_unified,
          :svn_diff_file_output_unified3,
          [ :stream, :diff, :string, :string, :string, :string, :string,
            :string, :int, :pool ],
          :error

      attach_function :string_output_unified,
          :svn_diff_mem_string_output_unified,
          [ :stream, :diff, :string, :string, :string,
            :counted_string, :counted_string, :pool ],
          :error
    end

  end

end
