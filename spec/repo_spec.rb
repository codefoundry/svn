require 'spec_helper'

describe Svn::Repo do

  context ".create" do

    it "complains about nil paths" do
      expect { Svn::Repo.create(nil) }.to raise_error(
          ArgumentError, /cannot be nil/
        )
    end

    it "will complain about already existing repositories" do
      expect { Svn::Repo.create(test_repo_path) }.to raise_error(
          ArgumentError, /existing repository/
        )
    end

    it "will not overwrite an existing path" do
      path = temp_path('existing')
      FileUtils.mkdir_p(temp_path('existing', 'content'))
      begin
        expect { Svn::Repo.create(path) }.to raise_error(
            Svn::DirectoryNotEmptyError, /exists/
          )
      ensure
        FileUtils.rm_rf(path)
      end
    end

    it "complains about invalid paths" do
      expect {
        invalid_path = temp_path( 'blah', 'blah', 'blah' )
        Svn::Repo.create( invalid_path )
      }.to( raise_error( Svn::PathNotFoundError) )
    end

    it "can create a new repository" do
      path = temp_path('new_repo')
      repo = Svn::Repo.create( path )
      begin
        repo.should be_a(Svn::Repo)
        repo.null?.should be_false
      ensure
        FileUtils.rm_rf(path) if File.exists? path
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
        Svn::Repo.open( temp_path( 'blah', 'blah' ) )
      }.to( raise_error( Svn::PathNotFoundError ) )
    end

    it "complains about paths inside the repository" do
      path = link_test_repo
      begin
        expect {
          Svn::Repo.open( File.join( test_repo_path, 'trunk', 'blah' ) )
        }.to( raise_error( Svn::PathNotFoundError ) )
      ensure
        unlink_test_repo(path)
      end
    end

    it "can open an existing repository" do
      path = link_test_repo
      begin
        repo = Svn::Repo.open(path)
        repo.should be_a(Svn::Repo)
        repo.null?.should be_false
      ensure
        unlink_test_repo( path )
      end
    end

  end

  context "#revision" do

    before do
      @path = link_test_repo
      @repo = open_test( @path )
    end

    after do
      unlink_test_repo( @path )
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
      rev = @repo.revision(1)
      rev.should be_a( Svn::Revision )
      rev.null?.should be_false
    end

  end

  context "#youngest" do
    
    before do
      @path = link_test_repo
      @repo = open_test( @path )
    end

    after do
      unlink_test_repo( @path )
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
