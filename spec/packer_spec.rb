require "packer" # local
require "spec_setup" # local
require "tmpdir" # stdlib
require "cabin"

Cabin::Channel.get.subscribe(STDOUT)

describe Packer do
  before :each do
    @tmpdir = Dir.mktmpdir
  end

  after :each do
    FileUtils.remove_entry_secure(@tmpdir)
  end

  def create_local_git
    Dir.chdir(@tmpdir) do
      system("git init")
      File.write("hello", "world")
      system("git add hello")
      system("git commit -am 'test'")
    end
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

  context "ruby-cabin as a package" do
    subject { Packer.new("https://github.com/jordansissel/ruby-cabin.git") }

    before do
      subject.fetch
      subject.build
    end

    after do
      subject.clean
    end

    it "should pass all tests" do
      # Run fpm's test suite from the packer's staging/app directory. 
      # Make sure it passes.
      Dir.chdir(subject.appdir) do
        system("bundle exec make test")
        insist { $? }.success?
      end
    end

    it "should include dependencies" do
      Dir.chdir(subject.appdir) do
        # Get the gem list, only the names though.
        gems = `bundle exec gem list --local`.split("\n")\
          .collect { |line| line.split(/\s+/).first }

        # This assumes ruby-cabin's Gemfile includes json, minitest, and
        # simplecov
        insist { gems }.include?("json")
        insist { gems }.include?("minitest")
        insist { gems }.include?("simplecov")
      end
    end
  end

  context "#fetch" do
    it "should fail if given an invalid git repo" do
      insist { Packer.new("/invalid").fetch }.raises(Packer::Error)
    end

    it "should fail if the workdir cannot be used" do
      # Create a local git repo
      insist { Packer.new(@tmpdir).workdir = "/invalid" } \
        .raises(Packer::WorkDirectoryProblem)
    end
  end

  context "#build" do
    it "should fail if bundler fails" do
      create_local_git
      File.write("Gemfile", ["source :rubygems", "gem 'invalid gem name'"])
      system("git add Gemfile")
      system("git commit -am 'test'")

      packer = Packer.new(@tmpdir)
      packer.fetch
      packer.build
    end
  end

  context "#assemble" do
    it "should produce a .tar.gz file"
  end

  context "#clean" do
    it "should completely purge the workdir"
  end
end
