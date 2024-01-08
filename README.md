# Waxwing

## Usage
Load Waxwing using the following code snippet.

```make
WAXWING := $(WORKDIR_DEPS)/waxwing/bin/waxwing
$(WAXWING):
	@echo "Loading Waxwing..."
	git clone git@github.com:ic-designer/bash-waxwing.git --branch main $(WORKDIR_DEPS)/waxwing
	@echo
```
