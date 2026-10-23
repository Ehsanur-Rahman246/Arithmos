CXX      ?= g++
CXXFLAGS ?= -std=c++17 -O2 -Wall -Wextra -Wpedantic
CASES    ?= ../docs/release-1-cases.json

ENGINES := src/shared/format_number.cpp src/calculator/calculator.cpp \
           src/programmer/programmer.cpp src/converter/units.cpp src/converter/converter.cpp
CLI     := src/cli/cli.cpp src/cli/pick.cpp src/cli/selector.cpp src/cli/terminal.cpp

all: arithmos

arithmos: $(ENGINES) $(CLI) src/main.cpp
	$(CXX) $(CXXFLAGS) -Isrc -o $@ $^

run_tests: $(ENGINES) $(CLI) test/run_cases.cpp
	$(CXX) $(CXXFLAGS) -Isrc -o $@ $^

run_selector: src/cli/selector.cpp src/cli/pick.cpp test/run_selector.cpp
	$(CXX) $(CXXFLAGS) -Isrc -o $@ $^

test: run_tests run_selector
	./run_tests $(CASES)
	./run_selector

asan: $(ENGINES) $(CLI) test/run_cases.cpp src/cli/selector.cpp
	$(CXX) -std=c++17 -g -O1 -fsanitize=address,undefined -Isrc -o run_tests_asan \
	  $(ENGINES) $(CLI) test/run_cases.cpp
	$(CXX) -std=c++17 -g -O1 -fsanitize=address,undefined -Isrc -o run_selector_asan \
	  src/cli/selector.cpp src/cli/pick.cpp test/run_selector.cpp
	./run_tests_asan $(CASES)
	./run_selector_asan

clean:
	rm -f arithmos run_tests run_selector run_tests_asan run_selector_asan

.PHONY: all test asan clean