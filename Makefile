.PHONY: lint test install

lint:
	shellcheck -x bin/backup-toolkit install.sh tests/integration.sh hooks/*/*.sh

test:
	tests/integration.sh

install:
	sudo ./install.sh
