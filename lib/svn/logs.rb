require 'time'
require 'rubygems'
require 'ffi'

module Svn #:nodoc:

  module Log

    extend FFI::Library

    NodeKind = enum( :none, :file, :dir, :unknown )
    Actions = enum(
        :added, 65,
        :deleted, 68,
        :replaced, 82,
        :modified, 77
      )

    # description of a changed path
    class ChangedPathStruct < FFI::Struct
      layout(
          :action, :char, # 'A'dd, 'D'elete, 'R'eplace, 'M'odify
          :copyfrom_path, :string,
          :copyfrom_rev, :long,
          :node_kind, NodeKind
        )

      # returns a character that represents the type of the change: :added,
      # :deleted, :replaced, :modified
      def action
        Actions[ self[:action] ]
      end

      # returns the path's node type (:none, :file, :dir, :unknown)
      def kind
        self[:node_kind]
      end

      # if the node was copied from another path/rev, returns the [path, rev]
      # pair or nil otherwise
      def copied_from
        [ self[:copyfrom_path], self[:copyfrom_rev] ] unless self[:copyfrom_rev] == -1
      end

      def to_h
        { :action => action, :kind => kind, :copied_from => copied_from }
      end
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

      def has_children?
        ( self[:has_children] == 1 )
      end

      def changed_paths
        @changed ||= (
            self[:changed_paths].null? ? nil : self[:changed_paths].to_h
          )
      end

      def props
        self[:rev_props]
      end

      def message
        props[ LOG_PROP_NAME ]
      end
      alias_method :log, :message

      def author
        props[ AUTHOR_PROP_NAME ]
      end

      def timestamp
        Time.parse( props[ TIMESTAMP_PROP_NAME ] )
      end
    end

    # create a mapped type for use elsewhere
    Entry = EntryStruct.by_ref

  end

end
