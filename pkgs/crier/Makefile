FENNEL?=$(fennel)
PREFIX?=/usr/local

PROGRAM_NAME=crier
MAIN=crier.fnl
SOURCES=$(MAIN) dbus-service.fnl

$(PROGRAM_NAME): $(SOURCES) Makefile
	(echo -e "#!/usr/bin/env lua\n" ; \
	 lua $(FENNEL) --require-as-include --compile $(MAIN) ) > $@
	chmod +x $@

install:
	mkdir -p $(PREFIX)/bin
	cp $(PROGRAM_NAME) $(PREFIX)/bin
