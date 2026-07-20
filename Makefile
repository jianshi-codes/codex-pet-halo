SHELL := /bin/bash

.PHONY: bootstrap generate build test m0-tests m2-tests m2-smoke m3-tests m3-smoke m4-tests m4-smoke m5-tests m5-smoke m6-tests m6-smoke m7-tests m7-smoke check validate-bundle validate-generated-project

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

m4-tests:
	./Scripts/m4-tests.sh

m4-smoke:
	./Scripts/m4-smoke.sh

m5-tests:
	./Scripts/m5-tests.sh

m5-smoke:
	./Scripts/m5-smoke.sh

m6-tests:
	./Scripts/m6-tests.sh

m6-smoke:
	./Scripts/m6-smoke.sh

m7-tests:
	./Scripts/m7-tests.sh

m7-smoke:
	./Scripts/m7-smoke.sh

validate-bundle:
	./Scripts/validate-bundle.sh

validate-generated-project:
	./Scripts/validate-generated-project.sh

check:
	./Scripts/check.sh
