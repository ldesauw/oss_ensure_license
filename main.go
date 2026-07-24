// Command endure-licence is a dummy program used to exercise hack/gen-licenses.sh.
// It pulls in a few dependencies with different licence types so the generated
// LICENSES/ folder has something meaningful to show.
package main

import (
	"fmt"

	"github.com/google/uuid"                  // BSD-3-Clause
	version "github.com/hashicorp/go-version" // MPL-2.0
	"github.com/pkg/errors"                   // BSD-2-Clause
	"github.com/sirupsen/logrus"              // MIT
)

func main() {
	logrus.SetFormatter(&logrus.TextFormatter{})

	id, err := uuid.NewRandom()
	if err != nil {
		logrus.WithError(errors.Wrap(err, "generating id")).Fatal("failed")
	}

	v, err := version.NewVersion("1.2.3")
	if err != nil {
		logrus.WithError(errors.Wrap(err, "parsing version")).Fatal("failed")
	}

	fmt.Printf("hello, id: %s, version: %s\n", id.String(), v.String())
}
