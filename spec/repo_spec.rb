require 'spec_helper'

describe Svn::Repo do

  context ".create" do

    after(&REMOVE_TMP_REPO)

    it "complains about nil paths" do
      expect { Svn::Repo.create(nil) }.to raise_error(
          ArgumentError, /cannot be nil/
        )
    end

    it "will not overwrite an existing path" do
      expect { Svn::Repo.create(TMP_PATH) }.to raise_error(
          Svn::DirectoryNotEmptyError, /exists/
        )
    end

    it "complains about invalid paths" do
      expect {
        invalid_path = File.join( TMP_PATH, 'blah', 'blah', 'blah' )
        Svn::Repo.create( invalid_path )
      }.to( raise_error( Svn::PathNotFoundError ) )
    end

    it "can create a new repository" do
      repo = Svn::Repo.create( TMP_REPO )
      repo.should be_a(Svn::Repo)
      repo.null?.should be_false
    end

  end

  context ".open" do

    before(&CREATE_TMP_REPO)
    after(&REMOVE_TMP_REPO)

    it "complains about nil paths" do
      expect {
        Svn::Repo.open(nil)
      }.to raise_error( ArgumentError, /cannot be nil/ )
    end

    it "complains about invalid paths" do
      expect {
        Svn::Repo.open( File.join( TMP_PATH, 'blah', 'blah' ) )
      }.to( raise_error( Svn::PathNotFoundError ) )
    end

    it "complains about paths inside the repository" do
      expect {
        Svn::Repo.open( File.join( TMP_REPO, 'trunk', 'blah' ) )
      }.to( raise_error( Svn::PathNotFoundError ) )
    end

    it "can open an existing repository" do
      repo = Svn::Repo.open(TMP_REPO)
      repo.should be_a(Svn::Repo)
      repo.null?.should be_false
    end

  end

  context "#revision" do

    before(&CREATE_TMP_REPO)
    after(&REMOVE_TMP_REPO)

    it "complains about invalid revision numbers" do
      repo = Svn::Repo.open( TMP_REPO )
      expect {
        repo.revision(10_000_000)
      }.to raise_error( Svn::InvalidRevisionError )
    end

    it "opens valid revisions" do
      repo = Svn::Repo.open( TMP_REPO )
      rev = repo.revision(0)
      rev.should be_a( Svn::Revision )
      rev.null?.should be_false
    end

  end

end
