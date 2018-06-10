#!/bin/bash
set -e

lua -lluacov test/unit/test_filter.lua -o TAP --failure
lua -lluacov test/unit/test_filters_advanced.lua -o TAP --failure
lua -lluacov test/unit/test_utils.lua -o TAP --failure
lua -lluacov test/unit/test_handler_mocking_openidc.lua -o TAP --failure
lua -lluacov test/unit/test_introspect.lua -o TAP --failure
lua -lluacov test/unit/test_utils_bearer_access_token.lua -o TAP --failure

