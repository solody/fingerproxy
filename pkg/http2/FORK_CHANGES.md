# Changes to `golang.org/x/net/http2`

This document records every intentional difference between upstream
[`golang.org/x/net/http2`](https://github.com/golang/net/tree/master/http2)
and the fork at `pkg/http2/`.

## Upstream baseline

| Item | Value |
| --- | --- |
| Upstream repository | https://github.com/golang/net |
| Synced tag | **v0.59.0** |
| Sync script | [`pkg/sync-http2-pkg.sh`](../sync-http2-pkg.sh) |
| Previous fork baseline | v0.33.0 |

`go.mod` requires `golang.org/x/net v0.59.0` (and Go **1.26+** via toolchain)
because the fork still imports public packages from that module
(`http/httpguts`, `http2/hpack`, etc.).

---

## Why fork at all?

Akamai-style HTTP/2 fingerprinting needs SETTINGS / WINDOW_UPDATE / PRIORITY /
HEADERS data from the connection. Those frames are handled inside unexported
`serverConn.processFrame`. Upstream does not expose hooks, so fingerproxy keeps
a local copy and instruments that function.

---

## Change categories

There are **three** kinds of changes in this fork:

1. **Metadata instrumentation** (fingerprinting) — functional patch in `server.go`
2. **Import path rewrites** — required so the fork compiles outside `golang.org/x/net`
3. **Vendored `internal/*` packages** — copies of upstream internals that Go’s
   `internal` visibility rules otherwise block

`sync-http2-pkg.sh` performs (2) and (3) automatically. **(1) must be re-applied
manually after each sync** (see below).

---

## 1. Metadata instrumentation (`server.go`)

### 1.1 Extra import

```go
"github.com/wi1dcard/fingerproxy/pkg/metadata"
```

### 1.2 Hook site: `(*serverConn).processFrame`

Protocol handling is unchanged: each `case` still ends with the original
`return sc.processXxx(f)`. Before that return, fingerproxy optionally writes
into `*metadata.Metadata` taken from `sc.baseCtx`
(`metadata.FromContext(sc.baseCtx)`).

`proxyserver` creates that context when ALPN negotiates `h2` and passes it via
`http2.ServeConnOpts.Context`.

#### `*SettingsFrame` (non-ACK only)

- Reads all settings via `NumSettings` / `Setting(i)`
- Stores `[]metadata.Setting` into `md.HTTP2Frames.Settings` (overwrite)

#### `*MetaHeadersFrame`

- Copies `f.Fields` into `md.HTTP2Frames.Headers`
- Builds `md.HTTP2Frames.HeaderOrder`: header **names** joined with `--->`
- If `f.HasPriority()`, appends one `metadata.Priority` from `f.Priority`

#### `*WindowUpdateFrame`

- Records the **first** connection-level increment only
  (`WindowUpdateIncrement == 0` guard)

#### `*PriorityFrame`

- Appends `metadata.Priority` from `f.PriorityParam`

No other frames are instrumented (`Ping`, `Data`, `RST`, `GoAway`,
`PushPromise`, `PriorityUpdate`, …).

### 1.3 Behavioral notes

- Sampling is side-effect free on the HTTP/2 state machine.
- Empty / missing context is ignored (`ok == false`).
- `HeaderOrder` is debugging / custom-header material; Akamai fingerprint
  string still comes from `HTTP2FingerprintingFrames.Marshal`.

### 1.4 Re-apply after sync

After running `pkg/sync-http2-pkg.sh`, restore the blocks in
`processFrame` (and the `metadata` import). Search for comments marked
`// fingerproxy:` in `server.go`, or diff against this document.

---

## 2. Import path rewrites

Upstream code imports `golang.org/x/net/internal/...`. Those packages are
**not importable** from `github.com/wi1dcard/fingerproxy`. The sync script
rewrites them to:

```text
golang.org/x/net/internal/<name>
  → github.com/wi1dcard/fingerproxy/pkg/http2/internal/<name>
```

### Files touched (import line only)

| File | Upstream import | Local import |
| --- | --- | --- |
| `server.go` | `.../internal/httpcommon` | `pkg/http2/internal/httpcommon` |
| `write.go` | `.../internal/httpcommon` | `pkg/http2/internal/httpcommon` |
| `transport.go` | `.../internal/httpcommon` | `pkg/http2/internal/httpcommon` |
| `export_test.go` | `.../internal/httpcommon` | `pkg/http2/internal/httpcommon` |
| `frame.go` | `.../internal/httpsfv` | `pkg/http2/internal/httpsfv` |
| `clientconn_test.go` | `.../internal/gate` | `pkg/http2/internal/gate` |
| `netconn_test.go` | `.../internal/gate` | `pkg/http2/internal/gate` |
| `testcert_test.go` | `.../internal/testcert` | `pkg/http2/internal/testcert` |

`server.go` also has the metadata import from §1 (not an import rewrite).

---

## 3. Vendored internal packages

Copied from `golang/net@v0.59.0/internal/` into `pkg/http2/internal/`:

| Package | Why |
| --- | --- |
| `httpcommon` | Used by server/transport/write (header / request helpers) |
| `httpsfv` | Used by `frame.go` (structured field values / priority) |
| `gate` | Used by http2 tests |
| `testcert` | Used by http2 tests |

These are **unmodified** upstream sources (aside from any self-imports rewritten
the same way, e.g. `gate` tests).

Also: root `LICENSE` from `golang/net` is copied into `pkg/http2/LICENSE` by
the sync script (upstream’s `http2/` directory does not always contain it).

---

## Sync workflow

```bash
# From repo root
./pkg/sync-http2-pkg.sh

# Then re-apply §1 metadata instrumentation in pkg/http2/server.go
# (script prints a reminder)

# Verify
go build -o fingerproxy ./cmd
go test ./pkg/proxyserver/ ./pkg/reverseproxy/ ./pkg/ja4/
```

To change the upstream version, edit `TAG=` in `sync-http2-pkg.sh` and bump
`golang.org/x/net` in `go.mod` to the same tag.

---

## Diff summary vs `golang.org/x/net@v0.59.0`

| Path | Diff kind |
| --- | --- |
| `server.go` | metadata hooks + `httpcommon` import rewrite |
| `frame.go` / `write.go` / `transport.go` / `*_test.go` | import rewrite only |
| `internal/httpcommon`, `httpsfv`, `gate`, `testcert` | full vendor (new tree) |
| `LICENSE` | added by sync script |

There are **no** intentional algorithm changes outside `processFrame`
instrumentation.

---

## Related fingerproxy code (not part of this fork)

These live outside `pkg/http2` but consume the captured metadata:

- `pkg/metadata` — `Metadata` / `HTTP2FingerprintingFrames` / context helpers
- `pkg/fingerprint` — JA3/JA4/H2 fingerprint + `HTTP2HeaderOrder` injector
- `pkg/proxyserver` — attaches metadata context on `h2` connections
- `fingerproxy.DefaultHeaderInjectors` — forwards `X-HTTP2-Header-Order`, etc.
