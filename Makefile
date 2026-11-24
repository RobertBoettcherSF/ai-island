# Robert's laptop: GNAT is gcc and gnatbind in /usr/bin, so `make test` is enough.
# If the Ada compiler has another name: make test ADA_DRIVER=gcc-12
GPRBUILD ?= gprbuild
ADA_DRIVER ?= gcc

.PHONY: all test clean wasm zip

all:
	$(GPRBUILD) -p -P island.gpr -XADA_DRIVER=$(ADA_DRIVER) -XMODE=dev

test:
	$(GPRBUILD) -p -P island.gpr -XADA_DRIVER=$(ADA_DRIVER) -XMODE=test
	$(GPRBUILD) -p -P tests/tests.gpr -XADA_DRIVER=$(ADA_DRIVER)
	./tests/smoke.sh

clean:
	rm -rf obj bin

wasm:
	./tools/build-wasm.sh

zip: all
	./tools/make-zip.sh
