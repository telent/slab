FENNEL?=$(fennel)
PREFIX?=/usr/local

PROGRAM_NAME=crier
MAIN=crier.fnl
SOURCES=$(MAIN) dbus-service.fnl

$(PROGRAM_NAME): $(SOURCES) Makefile
	(echo -e "#!/usr/bin/env lua\n" ; \
	: we reset package.path so that --require-as-include cannot find ; \
	: and inline third-party modules ; \
	lua -e 'package.path="./?.lua"' $(FENNEL) --require-as-include --compile $(MAIN) ) > $@
	chmod +x $@

install:
	mkdir -p $(PREFIX)/bin $(PREFIX)/lib/crier
	cp $(PROGRAM_NAME) $(PREFIX)/bin
	cp interface.xml styles.css $(PREFIX)/lib/crier
