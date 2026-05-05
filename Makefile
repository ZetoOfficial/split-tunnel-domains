.PHONY: validate build check

validate:
	sh scripts/validate.sh

build:
	sh scripts/build.sh

check: validate build
