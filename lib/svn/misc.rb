require 'rubygems'
require 'ffi'

module Svn #:nodoc:

  extend FFI::Library

  NodeKind = enum( :none, :file, :dir, :unknown )

  Actions = enum(
      :added, 65,
      :deleted, 68,
      :replaced, 82,
      :modified, 77
    )

  PathChangeKind = enum( :modified, :added, :deleted, :replaced, :reset )

  class ChangedPathStruct < FFI::Struct
    layout(
        :id, :pointer,
        :change_kind, PathChangeKind,
        :text_mods, :int,
        :prop_mods, :int,
        :node_kind, NodeKind,
        :copyfrom_known, :int,
        :copyfrom_rev, :long,
        :copyfrom_path, :string
      )

    def change_kind
      self[ :change_kind ]
    end

    def node_kind
      self[ :node_kind ]
    end

    def text_mods?
      ( self[ :text_mods ] == 1 )
    end

    def prop_mods?
      ( self[ :prop_mods ] == 1 )
    end

    def copyfrom_known?
      ( self[ :copyfrom_known ] == 1 )
    end

    def copied_from
      [ self[:copyfrom_path], self[:copyfrom_rev] ] unless copyfrom_known?
    end

    def to_h
      h = {
          :change_kind => change_kind,
          :node_kind => node_kind,
          :text_mods? => text_mods?,
          :prop_mods? => prop_mods?,
        }
      h.merge!( :copied_from => copied_from ) if copyfrom_known?
      h
    end
  end
  ChangedPath = ChangedPathStruct.by_ref

end
