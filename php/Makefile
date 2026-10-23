PHP ?= php

.PHONY: run test

run:
	$(PHP) bin/arithmos.php

# 175 shared cases + extras, then selector tests SL1-SL21 (+X2, X3)
test:
	$(PHP) test/run_cases.php ../docs/release-1-cases.json
	$(PHP) test/run_selector.php