# No find/mkdir needed: wildcards are expanded by make, and javac creates the -d folder itself.

# One entry per package folder (make's wildcard does not recurse).
SRC  := $(wildcard src/arithmos/*.java) \
        $(wildcard src/arithmos/cli/*.java) \
        $(wildcard src/arithmos/calculator/*.java) \
        $(wildcard src/arithmos/programmer/*.java) \
        $(wildcard src/arithmos/converter/*.java) \
        $(wildcard src/arithmos/shared/*.java)
TEST := $(wildcard test/arithmos/*.java)

# Class-path separator: ';' on Windows, ':' elsewhere.
ifeq ($(OS),Windows_NT)
  SEP := ;
  CLEAN := if exist out rmdir /s /q out & if exist out-test rmdir /s /q out-test
else
  SEP := :
  CLEAN := rm -rf out out-test
endif

.PHONY: build run test clean

build:
	javac -Xlint:all,-restricted -d out $(SRC)

run: build
	java --enable-native-access=ALL-UNNAMED -cp out arithmos.Main

test: build
	javac -Xlint:all,-restricted -d out-test -cp out $(TEST)
	java -cp "out$(SEP)out-test" arithmos.RunCases ../docs/release-1-cases.json
	java -cp "out$(SEP)out-test" arithmos.RunSelector

clean:
	$(CLEAN)