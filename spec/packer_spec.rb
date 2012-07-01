require "packer" # local
require "spec_setup" # local
require "tmpdir" # stdlib

describe Packer do
  before :each do
    @tmpdir = Dir.mktmpdir
  end

  after :each do
    FileUtils.remove_entry_secure(@tmpdir)
  end

  it "should permit packaging a local git repo" do
    # Create a local git repo
    Dir.chdir(@tmpdir) do
      system("git init")
      File.write("hello", "world")
      system("git add hello")
      system("git commit -am 'test'")
    end

    packer = Packer.new(@tmpdir)
    packer.fetch
    packer.build
    packer.clean
  end

  context "fizzle" do
    it "should permit packaging a remote git repo" do
      packer = Packer.new("https://github.com/jordansissel/fpm.git")
      packer.fetch
      packer.build

      # Run fpm's test suite from the packer's staging/app directory. 
      # Make sure it passes.
      Dir.chdir(packer.appdir) do
        system("bundle exec rspec")
        insist { $? }.success?
      end

      packer.clean
    end
  end

  it "should package all dependencies" do
  end

  context "#fetch" do
    it "should fail if given an invalid git repo"
    it "should fail if the workdir cannot be used"
  end

  context "#build" do
    it "should fail if bundler fails"
  end

  context "#assemble" do
    it "should produce a .tar.gz file"
  end

  context "#clean" do
    it "should completely purge the workdir"
  end
end
