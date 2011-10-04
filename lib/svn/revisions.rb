require 'rubygems'
require 'ffi'

module Svn #:nodoc:

  class Revision < Root

    def to_i
      revnum
    end

    module C
      extend FFI::Library
      ffi_lib 'libsvn_fs-1.so.1'

      typedef Root, :root
      typedef :long, :revnum

      attach_function :revnum,
          :svn_fs_revision_root_revision,
          [ :root ],
          :revnum
    end

    # use the C module for all bound methods
    bind_to C

    # get the numeric identifier for this revision
    bind :revnum

  end

end
