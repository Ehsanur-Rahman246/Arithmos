// Entry point: argv -> one-shot mode or the interactive menu.
package main

import (
	"os"

	"arithmos/internal/cli"
)

func main() {
	os.Exit(cli.Main(os.Args[1:], os.Stdin, os.Stdout, os.Stderr))
}