FENNEL?=$(fennel)
PREFIX?=/usr/local

MODULES=main.fnl

%.lua : %.fnl
	lua $(FENNEL) --compile $< > $@

saturn: $(patsubst %.fnl,%.lua,$(MODULES)) Makefile
	(echo -e "#!/usr/bin/env lua\n" ; cat main.lua ) > $@
	chmod +x $@

install:
	mkdir -p $(PREFIX)/bin
	cp saturn $(PREFIX)/bin
