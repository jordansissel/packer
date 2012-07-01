require "packer" # local
require "spec_setup" # local
require "tmpdir" # stdlib
require "cabin"


# If running ruby in debug mode (ruby -d), let's get debug stuff out of the logger.
if $DEBUG
  logger = Cabin::Channel.get
  logger.subscribe(STDOUT)
  logger.level = :debug
end

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
    before :all do
      @packer = Packer.new("https://github.com/jordansissel/fpm.git")
      @packer.fetch
      @packer.build
    end

    after :all do
      @packer.clean
    end

    it "should pass all tests" do
      # Run fpm's test suite from the packer's staging/app directory. 
      # Make sure it passes.
      Dir.chdir(@packer.appdir) do
        # According to 'bundle --help exec' you must use Bundle.with_clean_env
        # in order to have subprocesses run sanely outside of this current
        # bundler environment.
        Bundler.with_clean_env do
          # Run the fpm test suite from within the full package dir.
          system("bundle exec rspec")
        end
        insist { $? }.success?
      end
    end

    it "should include dependencies" do
      Dir.chdir(@packer.appdir) do
        # Get the gem list, only the names though.
        gems = Bundler.with_clean_env do 
          # Line format is '  * NAME (VERSION)' 
          # I want the name.
          `bundle list`.split("\n")\
            .collect { |line| line.gsub(/^\s+\*\s+/, "").split(/\s+/).first }
        end

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

  context "#pack" do
    it "should produce a .tar.gz file" do
      create_local_git
      packer = Packer.new(@tmpdir)
      file = packer.pack
      insist { file }.end_with?(".tar.gz")
      insist { File }.exists?(file)
      File.delete(file)
    end
  end

  context "#clean" do
    it "should completely purge the workdir" do
      create_local_git
      packer = Packer.new(@tmpdir)
      packer.fetch
      packer.build

      insist { File.directory?(packer.workdir) } == true
      packer.clean
      insist { File.directory?(packer.workdir) } == false
    end
  end
end
