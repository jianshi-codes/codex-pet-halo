SHELL := /bin/bash

.PHONY: bootstrap generate build test m0-tests check validate-bundle validate-generated-project

bootstrap:
	./Scripts/bootstrap.sh

generate:
	./Scripts/generate.sh

build:
	./Scripts/build.sh

test:
	./Scripts/test.sh

m0-tests:
	./Scripts/m0-tests.sh

validate-bundle:
	./Scripts/validate-bundle.sh

validate-generated-project:
	./Scripts/validate-generated-project.sh

check:
	./Scripts/check.sh
