// Command endure-licence is a dummy program used to exercise hack/gen-licenses.sh.
// It pulls in a few dependencies with different licence types so the generated
// LICENSES/ folder has something meaningful to show.
package main

import (
	"fmt"

	"github.com/google/uuid"     // BSD-3-Clause
	"github.com/pkg/errors"      // BSD-2-Clause
	"github.com/sirupsen/logrus" // MIT
)

func main() {
	logrus.SetFormatter(&logrus.TextFormatter{})

	id, err := uuid.NewRandom()
	if err != nil {
		logrus.WithError(errors.Wrap(err, "generating id")).Fatal("failed")
	}

	fmt.Println("hello, id:", id.String())
}
