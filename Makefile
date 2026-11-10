.PHONY: lint test install

lint:
	shellcheck -x bin/safekeep install.sh tests/integration.sh hooks/*/*.sh

test:
	tests/integration.sh

install:
	sudo ./install.sh
