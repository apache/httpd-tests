# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Project Overview
Apache HTTP Server test suite using Perl-based Apache::Test framework. Tests Apache 1.3.x through trunk with custom C modules and Perl test scripts.

## Build & Test Commands

**Setup (required once):**
```bash
perl Makefile.PL -apxs /path/to/apache/bin/apxs
```

**Run all tests:**
```bash
t/TEST
```

**Run specific test file:**
```bash
t/TEST t/apache/byterange3.t
```

**Run tests in directory:**
```bash
t/TEST t/php
```

**Start/stop test server manually:**
```bash
t/TEST -start
t/TEST -stop
```

**Clean generated files (required after Apache config changes):**
```bash
t/TEST -clean
```

**Run under debugger:**
```bash
t/TEST -d gdb
```

**Smoke testing (repeat N times):**
```bash
t/SMOKE -times=5 -verbose t/modules/rewrite.t
```

## Critical Non-Obvious Patterns

1. **C modules embed their own config**: C modules in `c-modules/*/mod_*.c` have Apache config embedded at the top within `#if CONFIG_FOR_HTTPD_TEST` blocks. This config is auto-extracted during test setup.

2. **Test harness generates config files**: `t/conf/httpd.conf` and `t/conf/extra.conf` are GENERATED from `.in` templates. Never edit the generated files directly - edit the `.in` files and run `t/TEST -clean`.

3. **Custom Makefile.PL arguments**: This project extends Apache::TestMM with custom args like `limitrequestline` and `limitrequestlinex2` (see Makefile.PL lines 30-43). These are NOT standard Apache::Test options.

4. **IPv4/6 confusion causes hangs**: If `t/TEST -start` hangs at "waiting for server to warm up" but port 8529 is reachable, comment out `::1` in `/etc/hosts`. The test server may listen on `0.0.0.0` only.

5. **SSL cert expiration**: If SSL tests fail, run `t/TEST -clean` to regenerate expired certificates. Remove `t/conf/ssl/ca` before cleaning if cert errors persist.

6. **Test file location matters**: Some tests modify DocumentRoot or create files in `t/htdocs/`. These tests cannot run against remote servers.

7. **Module detection via need_* functions**: Tests use `need_module`, `need_min_apache_version`, etc. from Apache::Test to skip when requirements aren't met. Check test file headers for these.

8. **Perl 5.28 on macOS homebrew hangs**: Use `/usr/bin/perl Makefile.PL` instead to avoid test suite hangs (see README line 195).

## Code Style

- **Strict mode**: ALL test files use `use strict; use warnings FATAL => 'all';`
- **Apache version conditionals**: Use `<IfDefine APACHE2>` in config, `need_min_apache_version()` in tests
- **Module conditionals**: Use `<IfModule @PHP_MODULE@>` syntax with @ placeholders in `.in` files
- **C module style**: Use `#ifdef APACHE1` / `#else` for version-specific code in C modules
- **debugging**: use `t_debug()` to add debug logging to assist in debugging with `t/TEST -v`.
- **assert style** Avoid bare `ok` checks and instead use `ok t_cmp(received, expected, comment)` so failures can be diagnosed quickly.
- **test style** when a number of relatedtests are needed, try to factor out inputs and validation into arrays or hashes leaving the body of 
  test to iteration over this data

## Test Framework Details

- Framework: Apache::Test (bundled in `Apache-Test/`)
- Test format: Perl `.t` files using `Test` module (not Test::More by default)
- Default port: 8529 (configurable via `-port`)
- Test server root: `t/` directory
- Generated configs: `t/conf/`
- Logs: `t/logs/`
