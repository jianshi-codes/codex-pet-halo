SHELL := /bin/bash

.PHONY: bootstrap generate build test m0-tests m2-tests m2-smoke m3-tests m3-smoke check validate-bundle validate-generated-project

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

m2-tests:
	./Scripts/m2-tests.sh

m2-smoke:
	./Scripts/m2-smoke.sh

m3-tests:
	./Scripts/m3-tests.sh

m3-smoke:
	./Scripts/m3-smoke.sh

validate-bundle:
	./Scripts/validate-bundle.sh

validate-generated-project:
	./Scripts/validate-generated-project.sh

check:
	./Scripts/check.sh
