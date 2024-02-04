.PHONY: check
check:
	gleam format && gleam test

.PHONY: fresh
fresh:
	gleam clean && gleam build && gleam run
