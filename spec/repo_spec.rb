require 'spec_helper'

describe Svn::Repo do

  context "#create" do

    it "should complain about a nil path" do
      expect { Svn::Repo.create(nil) }.to raise_error(
          Svn::RepositoryCreationFailedError, /cannot be nil/
        )
    end

    it "should not overwrite an existing path" do
      expect { Svn::Repo.create(TMP_PATH) }.to raise_error(
          Svn::RepositoryCreationFailedError, /exists/
        )
    end

    it "should complain about an invalid path" do
      expect {
        invalid_path = File.join( TMP_PATH, 'blah', 'blah', 'blah' )
        Svn::Repo.create( invalid_path )
      }.to(
          raise_error(
              Svn::RepositoryCreationFailedError, /No such file or directory/
            )
        )
    end

    it "should create a new repository" do
      repo = Svn.create(TMP_REPO)
      repo.should be_a(Svn::Repo)
    end

    after(&REMOVE_TMP_REPO)

  end

  context "#open" do
  end

end
