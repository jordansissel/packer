# Notes

Starting at the code and working backwards (code -> design -> requirements)

## Code

In the interests of time, I have omitted much code not strictly related to
"normal" function, this includes some input validation, sanity checks, etc.
In place of code, I have put TODO markers describing future improvements.

The tests pass for me both on
[travis-ci](http://travis-ci.org/#!/jordansissel/packer) and locally.

## Implementation Notes

* use of 'git clone' for every invocation (especially through post-commit
  hooks) suboptimal, especially for large repositories. A git fetch/pull for
  additional builds would likely reduce bandwidth and time spent in the fetch
  phase.
* the 'tarball' has unclear requirements. In the interest of time, I assumed the
  goal was simply to tar up the whole git directory (sans .git file) including
  dependencies.

## Requirements

### Clarity 

The requirements are unclear in some cases.

* 'any necessary dependencies' seems to indicate only ruby gem dependencies.
  What about libraries and other support tools? Are we relying on the main system
  to provide this? 
* there's no indication as to what the file name of the tarball should be.

### Deviation

Where necessary, I deviated from the requirements as follows:

* mentions 'standard convention of a Ruby project' which mentions a 'test'
  directory, but as I used rspec, I must needed to put tests in the 'spec'
  directory.
* my packer supports packaging git repositories as URLs as well as ones
  local on the filesystem.

## Design concerns

These are roughly concerns I came up with while reading the requirements and
implementing as code.

* Is building a package after every commit of a given project really a
  requirement?
* Unclear definition of 'tarball' as a package format. In general, they lack
  many properties (versioning, verification, queryable, known distribution
  tools, etc) useful when using software packages. 
* Monolithic packages are fairly beefy to ship (depending on how long your
  dependency list gets). Is this a problem? Do we have distribution mechanism
  that can help reduce the pain here?
* Are there any other systems we can use or learn from instead of inventing our own?
  Examples: heroku's buildpack, rpm/deb packaging ecosystems, gentoo portage, warbler.
* Taking the design requirements exactly as-is, I would probably implement 'packer' as
  a fairly short Makefile given the simplicity of the three steps (git clone,
  bundle install, tar it up)

## Related Thoughts

I've implemented packaging many times over, most of which culminated in writing
[fpm](https://github.com/jordansissel/fpm/).

If I could ignore the "write a tool called 'packer' as a ruby library"
requirement, the general goal of this project would fit well as an fpm package
source, with something like this going on:

`fpm -s ruby-git -t tar --source http://github.com/some/repo.git`

This would help us try out other target package formats than 'tar' trivially ;)
