require 'spec_helper'

describe Svn::Repo do

  context ".create" do

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
      begin
        repo = Svn::Repo.create( test_repo_path )
        repo.should be_a(Svn::Repo)
        repo.null?.should be_false
      ensure
        remove_test_repo
      end
    end

  end

  context ".open" do

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
        Svn::Repo.open( File.join( test_repo_path, 'trunk', 'blah' ) )
      }.to( raise_error( Svn::PathNotFoundError ) )
    end

    it "can open an existing repository" do
      create_test_repo

      repo = Svn::Repo.open(test_repo_path)
      repo.should be_a(Svn::Repo)
      repo.null?.should be_false
    end

  end

  context "#revision" do

    before do
      create_test_repo
      @repo = open_test_repo
    end

    after do
      remove_test_repo
    end

    it "complains about invalid revision numbers" do
      expect {
        @repo.revision(10_000_000)
      }.to raise_error( Svn::InvalidRevisionError )
    end

    it "opens valid revisions" do
      rev = @repo.revision(0)
      rev.should be_a( Svn::Revision )
      rev.null?.should be_false
    end

  end

  context "#youngest" do
    
    before do
      create_test_repo
      @repo = open_test_repo
    end

    after do
      remove_test_repo
    end

    it "returns a revision" do
      rev = @repo.youngest
      rev.should be_a( Svn::Revision )
      rev.null?.should be_false
    end

    it "is aliased as latest" do
      rev = @repo.latest
      rev.should be_a( Svn::Revision )
      rev.null?.should be_false
    end

  end

end
