#!/bin/bash

# Run backend in another shell first.
# go run ./backend

./testdata/gencert.sh

go build -o fingerproxy ./cmd
./fingerproxy -listen-addr :8443 -forward-url http://127.0.0.1:8080

# Now test the fingerproxy
# curl -k https://localhost:8443/
