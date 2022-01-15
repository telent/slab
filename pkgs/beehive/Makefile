FENNEL?=$(fennel)

MODULES=calls.fnl main.fnl

%.lua : %.fnl
	lua $(FENNEL) --compile $< > $@

beehive : $(patsubst %.fnl,%.lua,$(MODULES)) Makefile
	echo -e "#!/usr/bin/env lua\nrequire(\"main\")" > $@
	chmod +x $@
