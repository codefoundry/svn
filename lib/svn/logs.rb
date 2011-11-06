require 'time'
require 'rubygems'
require 'ffi'

module Svn #:nodoc:

  module Log

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

      # returns whether the "copied from" values are known
      def copyfrom_known?
        ( self[:copyfrom_rev] >= 0 )
      end

      # if the node was copied from another path/rev, returns the [path, rev]
      # pair or nil otherwise
      def copied_from
        [ self[:copyfrom_path], self[:copyfrom_rev] ] if copyfrom_known?
      end

      def to_h
        h = { :action => action, :kind => kind }
        h.merge!( :copied_from => copied_from ) if copyfrom_known?
        h
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

      # returns the revision number
      def rev
        self[:rev]
      end
      alias_method :num, :rev

      # returns whether this revision has children
      def has_children?
        ( self[:has_children] == 1 )
      end

      # returns a Hash of the revision's changed paths
      def changed_paths
        @changed_paths ||= ( self[:changed_paths].null? ? nil :
            self[:changed_paths].to_h.tap { |by_path|
                by_path.each_key { |k| by_path[k] = by_path[k].to_h }
              }
          )
      end

      # returns a Hash of the revision's properties
      def props
        @props ||= ( self[:rev_props].null? ? nil : self[:rev_props].to_h )
      end

      # return the revision's log message
      def message
        props[ LOG_PROP_NAME ] if props
      end
      alias_method :log, :message

      # return the revision's author
      def author
        props[ AUTHOR_PROP_NAME ] if props
      end

      # return the Time that this revision was committed
      def timestamp
        Time.parse( props[ TIMESTAMP_PROP_NAME ] ) if props
      end

      # get the contents of this log entry as a multi-level hash
      def to_h
        h = {
            :rev => rev,
            :log => message,
            :author => author,
            :timestamp => timestamp,
            :has_children? => has_children?,
          }
        h.merge!( :changed_paths => changed_paths ) if changed_paths
        h
      end
    end

    # create a mapped type for use elsewhere
    Entry = EntryStruct.by_ref

  end

end
