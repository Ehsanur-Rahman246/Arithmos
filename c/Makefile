CC      ?= cc
CFLAGS  ?= -std=c99 -Wall -Wextra -Wpedantic -O2
INC     = -Isrc
LIBS    = -lm
ENGINE  = src/shared/shared.c src/calculator/calculator.c src/programmer/programmer.c \
          src/converter/converter.c src/converter/units.c
CLI     = src/cli/cli.c src/cli/pick.c src/cli/select.c src/main.c
CASES  ?= ../docs/release-1-cases.json

all: arithmos

arithmos: $(ENGINE) $(CLI)
	$(CC) $(CFLAGS) $(INC) -o $@ $^ $(LIBS)

run_tests: $(ENGINE) test/run_cases.c
	$(CC) $(CFLAGS) $(INC) -o $@ $^ $(LIBS)

SELECTOR = src/shared/shared.c src/cli/select.c src/cli/pick.c

run_selector: $(SELECTOR) test/run_selector.c
	$(CC) $(CFLAGS) $(INC) -o $@ $^ $(LIBS)

test: run_tests run_selector arithmos
	./run_tests $(CASES)
	./run_selector
	sh test/cli_session.sh ./arithmos

# Same tests under AddressSanitizer + UBSan (gcc or clang).
asan:
	$(CC) -std=c99 -g -O1 -fsanitize=address,undefined -fno-sanitize-recover=all $(INC) \
	    -o run_tests_asan $(ENGINE) test/run_cases.c $(LIBS)
	ASAN_OPTIONS=detect_leaks=0 ./run_tests_asan $(CASES)
	$(CC) -std=c99 -g -O1 -fsanitize=address,undefined -fno-sanitize-recover=all $(INC) \
	    -o run_selector_asan $(SELECTOR) test/run_selector.c $(LIBS)
	ASAN_OPTIONS=detect_leaks=0 ./run_selector_asan

clean:
	rm -f arithmos run_tests run_tests_asan run_selector run_selector_asan

.PHONY: all test asan clean
