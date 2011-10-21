require 'rubygems'
require 'ffi'

module Svn #:nodoc:

  module Log

    extend FFI::Library

    NodeKind = enum( :none, :file, :dir, :unknown )

    # a changed path description
    class ChangedPathStruct < FFI::Struct
      layout(
          :action, :char, # 'A'dd, 'D'elete, 'R'eplace, 'M'odify
          :copyfrom_path, :string,
          :copyfrom_rev, :long,
          :node_kind, NodeKind
        )
    end

    # create a mapped type for use elsewhere
    ChangedPath = ChangedPathStruct.by_ref

    # A subversion log entry
    class EntryStruct < FFI::Struct
      layout(
          :old_changed_paths, AprHash.factory( :string, :pointer ),
          :rev, :long,
          :rev_props, AprHash.factory( :string, [:pointer, :string] ),
          :has_children, :int,
          :changed_paths, AprHash.factory( :string, ChangedPath )
        )

      def rev
        self[:rev]
      end
      alias_method :num, :rev

      def props
        self[:rev_props]
      end

      def has_children?
        ( self[:has_children] == 1 )
      end

      def changed_paths
        self[:changed_paths].to_h
      end
    end

    # create a mapped type for use elsewhere
    Entry = EntryStruct.by_ref

  end

end
