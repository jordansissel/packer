# packer

pack up a ruby project and its dependencies into a tarball.

<a href="http://travis-ci.org/#!/jordansissel/packer">
  <img src="https://secure.travis-ci.org/jordansissel/packer.png?branch=master">
</a>

## Usage

As a Ruby Library:

See the {Packer} class, but in general this is what you want:

```ruby

# The url is required, but the branch/tag/git-commit-sha1 is optional.
packer = Packer.new("https://github.com/jordansissel/fpm.git", "v0.3.10")

# Packer#pack builds the tarball (dependencies included) and returns the
# string path to the .tar.gz file produced.
tarball_path = packer.pack
```

---
Command line:

```
% packer [--revision SHA1|branch|tag] <url_or_path>
```

Takes a url or path to a git repository and packages it up as a tarball
including any dependencies resolvable with bundler..

When finished packing, it will put a .tar.gz file in the current directory.

---

Web hook:

* Run `foreman start server`
* Point github web hook at http://your-server:4567/

---

