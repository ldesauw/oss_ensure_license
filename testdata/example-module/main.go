// Copyright (c) OVH SAS. Licensed under the Apache License, Version 2.0.
//
// Command oss-ensure-license-example is a fixture module used to exercise the
// OSS Ensure License action and hack/gen-licenses.sh. It imports a few
// dependencies with different licence types (MIT, BSD-2, BSD-3, MPL-2.0) so
// the generated LICENSES/ folder has something meaningful to show. It is not
// part of the action itself.
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
