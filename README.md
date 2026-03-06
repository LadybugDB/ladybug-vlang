# ladybug-vlang

V bindings for LadybugDB via the C API (`lbug.h`)

## Setup

1. Run the build script

```bash
./build.vsh
```

2. Build or run V code with this module.

## API Coverage

Implemented high-level wrappers include:

- `open_database`, `Database.close`
- `connect`, `Connection.close`
- `Connection.query`, `Connection.prepare`, `Connection.execute`
- Prepared statement binders: `bind_bool`, `bind_int64`, `bind_int32`, `bind_float`, `bind_double`, `bind_string`, `bind_value`
- Query result helpers: `is_success`, `error_message`, `num_rows`, `num_columns`, `column_names`, `has_next`, `next_tuple`, `reset_iterator`, `summary`
- Tuple/value helpers for common scalar types (`bool`, `int32`, `int64`, `float`, `double`, `string`)
- Version helpers: `version`, `storage_version`

The raw C header is vendored at `ladybug/lbug.h` for signature compatibility.

## Example

```bash
v run examples/basic_usage.v
```

## V Shell

An interactive Ladybug shell is available at `shell-v/main.v` with:
- colored prompt/output
- history navigation + line editing (via V `readline`)
- tab autocomplete (shell commands + Cypher keywords)
- direct positional query for non-interactive runs

Run interactively:

```bash
v run shell-v/main.v -- test.db
```

Run a query directly (no stdin piping):

```bash
v run shell-v/main.v -- test.db 'RETURN "hello" AS msg;'
```

Shell commands use `.` prefixes (for example, `.schema`, `.help`, `.quit`).
