package main

import (
	"fmt"
	"log"
	"net/http"
	"sort"
)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")

		keys := make([]string, 0, len(r.Header))
		for k := range r.Header {
			keys = append(keys, k)
		}
		sort.Strings(keys)

		for _, k := range keys {
			for _, v := range r.Header[k] {
				fmt.Fprintf(w, "%s: %s\n", k, v)
			}
		}
	})

	addr := ":8080"
	log.Printf("listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, nil))
}
