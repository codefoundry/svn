require 'spec_helper'

describe Svn::Repo do

  context ".create" do

    after(&REMOVE_TMP_REPO)

    it "should complain about a nil path" do
      expect { Svn::Repo.create(nil) }.to raise_error(
          ArgumentError, /cannot be nil/
        )
    end

    it "should not overwrite an existing path" do
      expect { Svn::Repo.create(TMP_PATH) }.to raise_error(
          Svn::DirectoryNotEmptyError, /exists/
        )
    end

    it "should complain about an invalid path" do
      expect {
        invalid_path = File.join( TMP_PATH, 'blah', 'blah', 'blah' )
        Svn::Repo.create( invalid_path )
      }.to( raise_error( Svn::PathNotFoundError ) )
    end

    it "should create a new repository" do
      repo = Svn::Repo.create( TMP_REPO )
      repo.should be_a(Svn::Repo)
      repo.null?.should be_false
    end

  end

  context ".open" do

    before(&CREATE_TMP_REPO)
    after(&REMOVE_TMP_REPO)

    it "should complain about a nil path" do
      expect {
        Svn::Repo.open(nil)
      }.to raise_error( ArgumentError, /cannot be nil/ )
    end

    it "should complain about an invalid path" do
      expect {
        Svn::Repo.open( File.join( TMP_PATH, 'blah', 'blah' ) )
      }.to( raise_error( Svn::PathNotFoundError ) )
    end

    it "should complain about paths inside repository" do
      expect {
        Svn::Repo.open( File.join( TMP_REPO, 'trunk', 'blah' ) )
      }.to( raise_error( Svn::PathNotFoundError ) )
    end

    it "should open an existing repository" do
      repo = Svn::Repo.open(TMP_REPO)
      repo.should be_a(Svn::Repo)
      repo.null?.should be_false
    end

  end

end
