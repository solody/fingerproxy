# Use Fingerproxy as a Library

For the documentation, refer to [godoc](https://pkg.go.dev/github.com/wi1dcard/fingerproxy/pkg).

There are some vendored packages:

- Package `http2` is a fork of the http2 package in [`golang.org/x/net`](https://github.com/golang/net/tree/master/http2) (currently **v0.59.0**). Sync with [./sync-http2-pkg.sh](./sync-http2-pkg.sh), then re-apply metadata hooks documented in [./http2/FORK_CHANGES.md](./http2/FORK_CHANGES.md).
- Package `ja3` is cloned from <https://github.com/dreadl0ck/ja3>. See [./ja3/sync.sh](./ja3/sync.sh) for more info.

If you want to use them, please import from the origin.
