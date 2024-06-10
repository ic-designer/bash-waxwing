
_PATH := $(dir $(lastword $(MAKEFILE_LIST)))
WAXWING = $(abspath $(_PATH)/bin/waxwing)
