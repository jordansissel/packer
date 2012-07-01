require "rake"
require "cabin" # gem 'cabin'
require "fileutils" # stdlib

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

  # TODO(sissel): Problem encountered while creating the work directory.
  class WorkDirectoryProblem < Error; end

  # default methods to private, will make public methods explicit later.
  private

  # initialize a new Packer.
  #
  # source - a path or URL to a git repository.
  # branch_or_commit_hash - a git commit hash or branch name. If omitted,
  #   whatever 'git clone' obtains to will be used.
  def initialize(source, branch_or_commit_hash=nil)
    @source = source
    @revision = branch_or_commit_hash
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

    @workdir = path
  end # def workdir=

  # Get the work directory or a path relative to the work directory. This is
  # used for fetching files, building stuff, etc.
  #
  # If none is yet set, a random temporary directory will be generated using
  # Dir#mktmpdir.
  def workdir(path=nil)
    @workdir ||= Dir.mktmpdir
    if path.nil?
      return File.join(@workdir, path)
    else
      return @workdir
    end
  end # def workdir

  # Run a command, raise exception on failure.
  def run(*args)
    logger.time("Running", :command => args) do
      system(*args)
    end

    # Raise exception if the command failed.
    raise CommandFailed.new(args) if !$?.success?
  end # def run

  # Fetches the upstream git repository
  def fetch
    # Abort if workdir isn't empty?
    if Dir.new(workdir).count > 0
      raise WorkDirectoryNotEmpty(workdir)
    end

    # TODO(sissel): Ensure 'git' is in PATH

    Dir.chdir(workdir) do
      run("git", "clone", @source)
      run("git", "checkout", @revision)
    end
  end # def fetch

  def package_version
    # On the off chance that @revision is a git branch or tag, 
    # resolve the git revision.
    #
    # Using the 'short' rev seems reasonable for now. If not,
    # we can easily change it.
    return Dir.chdir(workdir) do
      @package_version ||= `git rev-parse --short #{@revision}`.chomp
    end
  end # def package_version

  # Perform any necessary build/compile actions to prepare for packaging.
  #
  # This includes installing and compiling any dependencies, etc.
  def build
    # Skip this step if there's no Gemfile.
    return unless File.exists?(File.join(workdir, "Gemfile"))

    # TODO(sissel): If there's a .bundle/config, delete it, bundler acts funny
    # sometimes otherwise.
    # TODO(sissel): If there's no Gemfile.lock, we could abort *or* we could do 
    # best-effort but still alert the user.
    # TODO(sissel): Run 'bundle install' and install to {workdir}/vendor
  end # def build

  # Assemble a package.
  #
  # Returns the path (String) to the package being emitted.
  def assemble
  end # def assemble

  # Clean any garbage on the filesystem created by this class.
  def clean
    @logger.info("Cleaning workdir", :path => workdir)
    FileUtils.remove_entry_secure(workdir)
  end # def clean

  public(:fetch, :logger, :workdir, :workdir=)
end # class Packer
