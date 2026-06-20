package main

import (
	"log"
	"net/http"
)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("Hello World\n"))
	})
	log.Fatal(http.ListenAndServe(":8080", nil))
}
