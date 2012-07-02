# packer

pack up a ruby project and its dependencies into a tarball.

<a href="http://travis-ci.org/#!/jordansissel/packer">
  <img src="https://secure.travis-ci.org/jordansissel/packer.png?branch=master">
</a>

## Usage

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

