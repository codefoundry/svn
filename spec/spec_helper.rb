# This file was generated by the `rspec --init` command. Conventionally, all
# specs live under a `spec` directory, which RSpec adds to the `$LOAD_PATH`.
# Require this file using `require "spec_helper.rb"` to ensure that it is only
# loaded once.
#
# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
end

# add the library path
$LOAD_PATH.unshift File.join(__FILE__, '..', 'lib')
require 'svn'

# print error codes/classes that are dynamically generated to stderr.
$debug_svn_errors = true

# create and destroy the test repo
TMP_PATH = '/tmp'
TEST_REPO = File.join( TMP_PATH, 'ruby_svn_test_repo' )

require 'fileutils'

def test_repo_path
  TEST_REPO
end

def create_test_repo
  Svn::Repo.create( test_repo_path )
end

def open_test_repo
  Svn::Repo.open( test_repo_path )
end

def remove_test_repo
  # clean up the temporary repository, if it is present
  FileUtils.rm_rf test_repo_path if File.exists? test_repo_path
end
