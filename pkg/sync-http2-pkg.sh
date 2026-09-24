#!/usr/bin/env -S bash -exuo pipefail

#
# Sync upstream http2 package (and required x/net internal deps) into this repo.
#
# golang.org/x/net/http2 depends on golang.org/x/net/internal/* which cannot be
# imported from outside the x/net module. We therefore also vendor those
# packages under ./http2/internal/ and rewrite import paths.
#

cd "$(dirname "$0")"

TAG=v0.59.0
TAG_ARCHIVE_FILENAME=$TAG.tar.gz
LOCAL_ARCHIVE_FILENAME=/tmp/$TAG_ARCHIVE_FILENAME

wget -O "$LOCAL_ARCHIVE_FILENAME" "https://github.com/golang/net/archive/refs/tags/$TAG_ARCHIVE_FILENAME"

TMP_SRCDIR=$(mktemp -d)
TARBALL_ROOTDIR=$(tar tf "$LOCAL_ARCHIVE_FILENAME" | head -n1)

tar xzf "$LOCAL_ARCHIVE_FILENAME" --directory "$TMP_SRCDIR"

UPSTREAM="$TMP_SRCDIR/$TARBALL_ROOTDIR"

rsync -avhW --no-compress --delete "$UPSTREAM/http2/" ./http2/
rsync -avhW --no-compress "$UPSTREAM/LICENSE" ./http2/

# Vendor internal packages required by http2 (cannot import x/net/internal/*).
mkdir -p ./http2/internal
for pkg in httpcommon httpsfv gate testcert; do
	rsync -avhW --no-compress --delete "$UPSTREAM/internal/$pkg/" "./http2/internal/$pkg/"
done
chmod -R u+w ./http2/internal

# Rewrite internal import paths so the fork compiles outside golang.org/x/net.
find ./http2 -name '*.go' -print0 | xargs -0 perl -pi -e \
	's|"golang.org/x/net/internal/(\w+)"|"github.com/wi1dcard/fingerproxy/pkg/http2/internal/$1"|g'

rm -rf "$TMP_SRCDIR"

cat <<'EOF'

Synced upstream http2.

IMPORTANT: re-apply fingerproxy metadata instrumentation in http2/server.go
(processFrame). See pkg/http2/FORK_CHANGES.md for the full patch description.
EOF
