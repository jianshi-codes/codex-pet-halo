SHELL := /bin/bash

.PHONY: bootstrap generate build test m0-tests m2-tests m2-smoke m3-tests m3-smoke m4-tests m4-smoke pet-following-tests pet-following-smoke pet-following-gate m7-tests m7-smoke m8-tests m8-smoke public-exposure-audit check validate-bundle validate-generated-project release-build release-archive release-checksum release-sign release-notarize release-verify release-launch-smoke

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

pet-following-tests:
	./Scripts/pet-following-tests.sh

pet-following-smoke:
	./Scripts/pet-following-smoke.sh

pet-following-gate: pet-following-tests pet-following-smoke

m7-tests: pet-following-tests

m7-smoke: pet-following-smoke

m8-tests:
	./Scripts/m8-tests.sh

m8-smoke:
	./Scripts/m8-smoke.sh

public-exposure-audit:
	python3 ./Scripts/public-exposure-audit.py

release-build:
	./Scripts/release-build.sh

release-archive:
	./Scripts/release-archive.sh

release-checksum:
	./Scripts/release-checksum.sh

release-sign:
	./Scripts/release-sign.sh

release-notarize:
	./Scripts/release-notarize.sh

release-verify:
	./Scripts/release-verify.sh

release-launch-smoke:
	./Scripts/release-launch-smoke.sh

validate-bundle:
	./Scripts/validate-bundle.sh

validate-generated-project:
	./Scripts/validate-generated-project.sh

check:
	./Scripts/check.sh
