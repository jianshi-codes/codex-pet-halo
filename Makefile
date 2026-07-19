SHELL := /bin/bash

.PHONY: bootstrap generate build test m0-tests check validate-bundle

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

check:
	./Scripts/check.sh
