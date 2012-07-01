require "rake" # gem/stdlib
require "cabin" # gem 'cabin'
require "fileutils" # stdlib
require "tmpdir" # stdlib, provides Dir#mktmpdir

# A ruby application packer.
#
# Given git repo path or url, this class provides a tarball of that repo
# including all dependencies.
#
# This class uses temporary storage to stage downloads while building the
# package. 
class Packer

  # The parent class of all Packer errors.
  class Error < StandardError; end

  # Problem encountered while creating the work directory.
  class WorkDirectoryProblem < Error; end

  # Thrown when a work directory given is not empty.
  class WorkDirectoryNotEmpty < Error; end

  # Thrown when an external command fails.
  class CommandFailed < Error; end

  # default methods to private, will make public methods explicit later.
  private

  attr_reader :name

  # initialize a new Packer.
  #
  # source - a path or URL to a git repository.
  # branch_or_commit_hash - a git commit hash or branch name. If omitted,
  #   whatever 'git clone' obtains to will be used.
  def initialize(source, branch_or_commit_hash=nil)
    @source = source
    @revision = branch_or_commit_hash || "HEAD"

    # Convert url/path/thing.git to simply 'thing'
    @name = @source.split("/").last.split(".").first
  end # def initialize

  # Get the logger. 
  #
  # By default, this will be a Cabin::Channel.
  def logger
    return @logger ||= Cabin::Channel.get
  end # def logger

  # Set the work directory to a given path.
  #
  # * The parent directory MUST exist, will raise 1Gj.
  # * If the path itself does not exist, it will be created.
  # * This path can be destroyed by invoking Packer#clean
  def workdir=(path)
    begin
      # Create the directory if it doesn't exist.
      # - permissions issues
      # - 'path' may not exist.
      # - 'path' may be a file, not a directory
      if !File.directory?(path)
        Dir.mkdir(path)
      end

      # Test writing to the directory.
      testfile = File.join(path, "test")
      File.new(testfile, "w") { }
      File.delete(testfile)
    rescue SystemCallError => e
      raise WorkDirectoryProblem.new(e)
    end

    # Use File.expand_path to avoid any relative-path problems later
    @workdir = File.expand_path(path)
  end # def workdir=

  # Get the work directory or a path relative to the work directory. This is
  # used for fetching files, building stuff, etc.
  #
  # If none is yet set, a random temporary directory will be generated using
  # Dir#mktmpdir.
  def workdir(path=nil)
    # Use File.expand_path to avoid any relative-path problems later
    @workdir ||= File.expand_path(Dir.mktmpdir)

    if path.nil?
      return @workdir
    else
      return File.join(@workdir, path)
    end
  end # def workdir

  # Get the application directory (where things are checked out, etc)
  def appdir(path=nil)
    dir = workdir("app")
    Dir.mkdir(dir) if !File.directory?(dir)
    if path.nil?
      return dir
    else
      return File.join(dir, path)
    end
  end # def clonedir

  # Run a command, raise exception on failure.
  def run(*args)
    logger.info("Running", :command => args)
    system(*args)

    # Raise exception if the command failed.
    raise CommandFailed.new(args) if !$?.success?
  end # def run

  # Fetches the upstream git repository
  def fetch
    # TODO(sissel): Ensure 'git' is in PATH

    # Skip fetch if there's already a .git directory.
    if File.directory?(appdir(".git"))
      logger.debug("Skipping fetch, .git directory already exists.", :path => appdir(".git"))
      return
    end
    
    # Dir#count includes "." and "..", so an empty directory has a count of 2.
    if Dir.new(appdir).count != 2
      raise WorkDirectoryNotEmpty.new(appdir)
    end

    Dir.chdir(appdir) do
      run("git", "clone", @source, ".")
      # Only invoke 'checkout' if a revision/branch/tag/commit is given.
      run("git", "checkout", @revision) if !@revision.nil?
    end
  end # def fetch

  # Get the package version.
  #
  # As of right now, the 'version' is the shortened git sha1 as
  # returned by 'git rev-parse --short <thing>'
  def version
    # On the off chance that @revision is a git branch or tag, 
    # resolve the git revision.
    #
    # Using the 'short' rev seems reasonable for now. If not,
    # we can easily change it.
    Dir.chdir(appdir) do
      fetch if !File.directory?(".git")
      @package_version ||= `git rev-parse --short #{@revision}`.chomp
    end

    return @package_version
  end # def version

  # Perform any necessary build/compile actions to prepare for packaging.
  #
  # This includes installing and compiling any dependencies, etc.
  def build
    # TODO(sissel): Bundler sometimes tries to be so smart as to be dumb,
    # so I may expect that we'll have to do the following in the future:
    # - prior to run, purge ./.bundle/config
    # - prior to run, if no Gemfile.lock, create it with 'bundle install'

    Dir.chdir(appdir) do
      if !File.exists?("Gemfile")
        @logger.info("Skipping bundler step, no Gemfile", :path => @appdir)
        return
      end

      # Don't use 'bundle install --development' because that implies some
      # constraints that aren't relevant to most "vendor these gems" actions.
      # After studying the bundler code and using it a sufficient amount of time,
      # I find that '--deployment' enforces policies I don't care about while
      # otherwise setting only "path = vendor/bundle" 
      # -Jordan
      Bundler.with_clean_env do
        run("bundle", "install", "--path", File.join(appdir, "vendor", "bundle"))
      end
    end
  end # def build

  # Assemble a package.
  #
  # Returns the path (String) to the package being emitted.
  def assemble(output_path)
    @logger.info("Assembling tarball", :name => name, :version => version, :output => output_path)
    run("tar", "-zcf", output_path, "--exclude", ".git",
        "-C", appdir, ".")
    return output_path
  end # def assemble

  # Clean any garbage on the filesystem created by this class.
  def clean
    @logger.info("Cleaning workdir", :path => workdir)
    FileUtils.remove_entry_secure(workdir)
  end # def clean

  # Run all the steps necessary to download, build, package, and clean up.
  #
  # Returns the string path to the tarball produced.
  def pack(output_path=default_output_path)
    fetch
    build
    tarball = assemble(output_path)
    clean
    return tarball
  end # def pack

  # Get the default package output path.
  #
  # Returns a string.
  def default_output_path
    return File.join(Dir.pwd, "#{name}-#{version}.tar.gz")
  end # def default_output_path

  # Main entry points
  public(:fetch, :build, :assemble, :pack, :clean)
  
  # Accessory methods
  public(:logger, :workdir, :workdir=, :appdir, :name, :version)
end # class Packer
