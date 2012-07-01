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
      yield if block_given?

      system("git add .")
      system("git commit -am 'test'")
    end
  end

  it "should permit packaging a local git repo" do
    create_local_git

    packer = Packer.new(@tmpdir)
    packer.fetch
    packer.build
    packer.clean
  end

  context "fpm as a package" do
    subject { Packer.new("https://github.com/jordansissel/fpm.git") }

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
        # Run the fpm test suite from within the full package dir.
        system("bundle exec rspec")
        insist { $? }.success?
      end
    end

    it "should include dependencies" do
      Dir.chdir(subject.appdir) do
        # Get the gem list, only the names though.
        gems = `bundle exec gem list --local`.split("\n")\
          .collect { |line| line.split(/\s+/).first }

        insist { gems }.include?("json")
        insist { gems }.include?("cabin")
        insist { gems }.include?("backports")
        insist { gems }.include?("arr-pm")
        insist { gems }.include?("clamp")
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
      create_local_git do
        File.write("Gemfile", ["source :rubygems", "gem 'invalid gem name'"].join("\n"))
      end

      packer = Packer.new(@tmpdir)
      packer.fetch

      # Bundler should fail in the build step..
      insist { packer.build }.raises(Packer::CommandFailed)
    end
  end

  context "#assemble" do
    it "should produce a .tar.gz file"
  end

  context "#clean" do
    it "should completely purge the workdir"
  end
end
