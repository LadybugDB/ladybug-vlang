module main

import ladybug
import os
import readline
import strings
import term

const default_prompt = 'lbug> '
const continuation_prompt = '..> '
const default_history_name = 'history.txt'

const shell_commands = [
	'.help',
	'.clear',
	'.quit',
	'.exit',
	'.max_rows',
	'.mode',
	'.stats',
	'.schema',
	'.multiline',
	'.singleline',
	'.highlight',
	'.render_errors',
	'.render_completion',
]

const cypher_keywords = [
	'CALL ',
	'CREATE ',
	'DELETE ',
	'DETACH DELETE ',
	'MATCH ',
	'MERGE ',
	'OPTIONAL MATCH ',
	'RETURN ',
	'SET ',
	'UNION ',
	'UNWIND ',
	'WITH ',
	'WHERE ',
	'ORDER BY ',
	'LIMIT ',
	'SKIP ',
	'LOAD FROM ',
]

const create_prefixes = ['CREATE ', 'DROP ', 'ALTER ']

enum CompletionContext {
	normal
	table_name
	property_name
}

struct CompletionEngine {
mut:
	table_names      []string
	node_table_names []string
	rel_table_names  []string
	property_names   []string
}

enum TableLookupScope {
	any
	node
	rel
}

enum OutputMode {
	box
	table
	column
	csv
	tsv
	list
	line
	json
	jsonlines
	trash
}

struct ShellConfig {
mut:
	database_path string = ':memory:'
	history_path  string
	stats         bool       = true
	mode          OutputMode = .box
	max_rows      int        = 20
	read_only     bool
	init_file     string = '.lbugrc'
	query_args    []string
}

struct Shell {
mut:
	r            readline.Readline
	db           ladybug.Database
	conn         ladybug.Connection
	cfg          ShellConfig
	completion   &CompletionEngine = unsafe { nil }
	history_file string
	last_history string
	multiline    bool = true
	continuation string
	quit         bool
}

fn main() {
	main_impl() or {
		eprintln(term.red('Error: ${err}'))
		exit(1)
	}
}

fn main_impl() ! {
	cfg := parse_args(os.args[1..])!
	mut shell := new_shell(cfg)!
	defer {
		shell.close()
	}
	shell.run()
}

fn parse_args(args []string) !ShellConfig {
	mut cfg := ShellConfig{}
	mut positional := []string{}
	mut i := 0
	for i < args.len {
		arg := args[i]
		l := arg.to_lower()
		match l {
			'--' {
				if i + 1 < args.len {
					positional << args[i + 1..]
				}
				break
			}
			'-h', '--help' {
				print_usage()
				exit(0)
			}
			'-v', '--version' {
				println('Lbug ${ladybug.version()}')
				exit(0)
			}
			'-r', '--readonly', '--read_only' {
				cfg.read_only = true
			}
			'-s', '--nostats', '--no_stats' {
				cfg.stats = false
			}
			'-p', '--path_history' {
				i++
				if i >= args.len {
					return error('flag ${arg} requires an argument')
				}
				cfg.history_path = args[i]
			}
			'-m', '--mode' {
				i++
				if i >= args.len {
					return error('flag ${arg} requires an argument')
				}
				cfg.mode = parse_mode(args[i])!
			}
			'-i', '--init' {
				i++
				if i >= args.len {
					return error('flag ${arg} requires an argument')
				}
				cfg.init_file = args[i]
			}
			else {
				if arg.starts_with('-') {
					return error('unknown option: ${arg}')
				}
				positional << args[i..]
				break
			}
		}
		i++
	}
	if positional.len > 0 {
		if cfg.database_path == ':memory:' && !is_query_token(positional[0]) {
			cfg.database_path = positional[0]
			if positional.len > 1 {
				cfg.query_args << positional[1..].join(' ')
			}
		} else {
			cfg.query_args << positional.join(' ')
		}
	}
	cfg.history_path = resolve_history_file(cfg.history_path)
	return cfg
}

fn is_query_token(token string) bool {
	upper := token.trim_space().to_upper()
	if upper.len == 0 {
		return false
	}
	if upper.starts_with('.') {
		return true
	}
	for kw in ['CALL', 'CREATE', 'DELETE', 'DETACH', 'DROP', 'MATCH', 'MERGE', 'OPTIONAL', 'RETURN',
		'SET', 'UNION', 'UNWIND', 'WITH', 'WHERE', 'ORDER', 'LIMIT', 'SKIP', 'LOAD'] {
		if upper.starts_with(kw) {
			return true
		}
	}
	return upper.contains(';')
}

fn resolve_history_file(path_arg string) string {
	if path_arg.len > 0 {
		base := if path_arg.ends_with(os.path_separator.str()) {
			path_arg
		} else {
			path_arg + os.path_separator.str()
		}
		return base + default_history_name
	}
	cwd_history := os.join_path(os.getwd(), default_history_name)
	if os.exists(cwd_history) {
		return cwd_history
	}
	home := os.home_dir()
	if home.len == 0 {
		return default_history_name
	}
	dir := os.join_path(home, '.lbdb')
	os.mkdir_all(dir) or {}
	return os.join_path(dir, default_history_name)
}

fn parse_mode(name string) !OutputMode {
	return match name.to_lower() {
		'box' { .box }
		'table' { .table }
		'column' { .column }
		'csv' { .csv }
		'tsv' { .tsv }
		'list' { .list }
		'line' { .line }
		'json' { .json }
		'jsonlines' { .jsonlines }
		'trash' { .trash }
		else { return error('unknown mode: ${name}') }
	}
}

fn print_usage() {
	println('Lbug shell (V implementation)')
	println('Usage: lbug [options] [database_path] [query]')
	println('Options:')
	println('  -h, --help               Show this help message')
	println('  -v, --version            Print version and exit')
	println('  -r, --read_only          Open database read-only')
	println('  -p, --path_history PATH  Set history directory')
	println('  -m, --mode MODE          Set output mode (box|table|column|csv|tsv|list|line|json|jsonlines|trash)')
	println('  -s, --no_stats           Disable query stats')
	println('  -i, --init FILE          Run startup commands from file (default: .lbugrc)')
	println('  QUERY                    Optional query to execute directly (what is left after option parsing)')
}

fn new_shell(cfg ShellConfig) !Shell {
	mut sys_cfg := ladybug.default_system_config()
	sys_cfg.read_only = cfg.read_only
	mut db := ladybug.open_database(cfg.database_path, sys_cfg)!
	mut conn := ladybug.connect(mut db)!
	println(opening_message(cfg.database_path, cfg.read_only))
	mut shell := Shell{
		db:           db
		conn:         conn
		cfg:          cfg
		history_file: cfg.history_path
	}
	mut completion := &CompletionEngine{}
	shell.completion = completion
	shell.r.skip_empty = true
	shell.r.previous_lines << []rune{}
	shell.r.previous_lines << []rune{}
	shell.r.completion_callback = fn [completion] (prefix string) []string {
		return completion.complete(prefix)
	}
	shell.refresh_completion_catalog()
	shell.load_history()!
	shell.process_file_if_present(cfg.init_file)
	return shell
}

fn opening_message(path string, read_only bool) string {
	mode := if read_only { 'read-only' } else { 'read-write' }
	if path == ':memory:' {
		return term.bright_black('Opening the database under in-memory mode (${mode}).')
	}
	return term.bright_black('Opening the database at path: ${path} in ${mode} mode.')
}

fn (mut s Shell) close() {
	s.conn.close()
	s.db.close()
}

fn (mut s Shell) run() {
	if s.cfg.query_args.len > 0 {
		for q in s.cfg.query_args {
			s.execute_input(q)
			if s.quit {
				break
			}
		}
		return
	}
	for !s.quit {
		prompt := if s.continuation.len == 0 || !s.multiline {
			default_prompt
		} else {
			continuation_prompt
		}
		line := s.r.read_line(prompt) or {
			println('')
			break
		}
		s.execute_input(line)
	}
}

fn (mut s Shell) process_file_if_present(path string) {
	if path.len == 0 || !os.exists(path) {
		return
	}
	println(term.bright_black('-- Processing: ${path}'))
	content := os.read_file(path) or {
		eprintln(term.red('Warning: cannot open init file: ${path}'))
		return
	}
	for line in content.split_into_lines() {
		s.execute_input(line)
		if s.quit {
			break
		}
	}
}

fn (mut s Shell) execute_input(raw_input string) {
	input := raw_input.trim_space()
	if input.len == 0 {
		return
	}
	if s.continuation.len > 0 {
		s.continuation += '\n' + input
	} else {
		s.continuation = input
	}
	if s.multiline && !statement_complete(s.continuation) {
		return
	}
	mut statement := s.continuation
	s.continuation = ''
	statement = statement.trim_space()
	if statement.len == 0 {
		return
	}
	if statement.starts_with('.') {
		s.handle_shell_command(statement)
		return
	}
	s.append_history(statement)
	s.execute_query_statement(statement)
}

fn (mut s Shell) handle_shell_command(line string) {
	parts := line.split(' ')
	cmd := parts[0].to_lower()
	arg := if parts.len > 1 { line.all_after_first(' ').trim_space() } else { '' }
	match cmd {
		'.help' {
			println('    .help     get command list')
			println('    .clear     clear shell')
			println('    .quit     exit from shell')
			println('    .max_rows [max_rows]     set maximum number of rows for display (default: 20)')
			println('    .mode [mode]     set output mode (default: box)')
			println('    .stats [on|off]     toggle query stats on or off')
			println('    .multiline     set multiline mode (default)')
			println('    .singleline     set singleline mode')
			println('    .schema     print database schema')
		}
		'.clear' {
			term.clear()
		}
		'.quit', '.exit' {
			s.quit = true
		}
		'.max_rows' {
			match arg {
				'' {
					eprintln(term.red('Error: .max_rows requires a number'))
				}
				else {
					max_rows := arg.int()
					s.cfg.max_rows = if max_rows <= 0 { 20 } else { max_rows }
					println(term.bright_black('maxRows set as ${s.cfg.max_rows}'))
				}
			}
		}
		'.mode' {
			if arg.len == 0 {
				print_modes()
				return
			}
			s.cfg.mode = parse_mode(arg) or {
				eprintln(term.red('Error: ${err}'))
				return
			}
			println(term.bright_black('mode set as ${arg.to_lower()}'))
		}
		'.stats' {
			match arg.to_lower() {
				'on' {
					s.cfg.stats = true
					println(term.bright_black('stats set as on'))
				}
				'off' {
					s.cfg.stats = false
					println(term.bright_black('stats set as off'))
				}
				else {
					eprintln(term.red('Error: .stats expects on|off'))
				}
			}
		}
		'.multiline' {
			s.multiline = true
			println(term.bright_black('multiline mode enabled'))
		}
		'.singleline' {
			s.multiline = false
			println(term.bright_black('singleline mode enabled'))
		}
		'.schema' {
			s.execute_query_statement('CALL show_tables() RETURN *;')
		}
		'.highlight', '.render_errors', '.render_completion' {
			println(term.bright_black('${cmd} is accepted for compatibility in this V shell.'))
		}
		else {
			eprintln(term.red('Error: unknown command: ${cmd}'))
		}
	}
}

fn print_modes() {
	println('Available output modes:')
	println('    box (default):    Tables using unicode box-drawing characters')
	println('    table:    Tables using ASCII characters')
	println('    column:    Output in columns')
	println('    csv:    Comma-separated values')
	println('    tsv:    Tab-separated values')
	println('    list:    Values delimited by "|"')
	println('    line:    One value per line')
	println('    json:    Results in a JSON array')
	println('    jsonlines:    Results in a NDJSON format')
	println('    trash:    No output')
}

fn (mut s Shell) execute_query_statement(query string) {
	mut result := s.conn.query(query) or {
		eprintln(term.red('Error: ${err}'))
		return
	}
	defer {
		result.close()
	}
	s.print_result(mut result)
	if should_refresh_catalog(query) {
		s.refresh_completion_catalog()
	}
}

fn (mut s Shell) print_result(mut result ladybug.QueryResult) {
	if s.cfg.mode == .trash {
		print_stats(result, s.cfg.stats)
		return
	}
	cols := int(result.num_columns())
	mut headers := result.column_names() or { []string{} }
	if headers.len == 0 && cols > 0 {
		headers = []string{len: cols, init: 'col'}
	}
	mut rows := [][]string{}
	mut total_rows := 0
	for result.has_next() {
		total_rows++
		if rows.len >= s.cfg.max_rows {
			continue
		}
		mut tuple := result.next_tuple() or { break }
		mut row := []string{cap: cols}
		for i in 0 .. cols {
			mut v := tuple.value(u64(i)) or {
				row << '<err>'
				continue
			}
			row << value_to_text(v)
			v.close()
		}
		tuple.close()
		rows << row
	}
	match s.cfg.mode {
		.csv { print_delimited(headers, rows, `,`, true) }
		.tsv { print_delimited(headers, rows, `\t`, false) }
		.list { print_delimited(headers, rows, `|`, false) }
		.line { print_line_mode(headers, rows) }
		.column { print_column(headers, rows, false) }
		.table { print_table(headers, rows, false) }
		.json { print_json(headers, rows, false) }
		.jsonlines { print_json(headers, rows, true) }
		else { print_table(headers, rows, true) }
	}
	print_tuple_count(total_rows, rows.len)
	print_stats(result, s.cfg.stats)
}

fn print_stats(result ladybug.QueryResult, enabled bool) {
	if !enabled {
		return
	}
	mut summary := result.summary() or { return }
	defer {
		summary.close()
	}
	println(term.bright_black('(${summary.compiling_time_ms():.2f} ms compile, ${summary.execution_time_ms():.2f} ms exec)'))
}

fn print_tuple_count(total int, shown int) {
	if total == shown {
		println(term.bright_black('(${total} tuples)'))
		return
	}
	println(term.bright_black('(${total} tuples, ${shown} shown)'))
}

fn print_delimited(headers []string, rows [][]string, sep u8, csv_escape bool) {
	sep_s := sep.ascii_str()
	println(headers.map(if csv_escape { csv_cell(it) } else { it }).join(sep_s))
	for row in rows {
		println(row.map(if csv_escape { csv_cell(it) } else { it }).join(sep_s))
	}
}

fn csv_cell(v string) string {
	if v.contains(',') || v.contains('"') || v.contains('\n') {
		return '"' + v.replace('"', '""') + '"'
	}
	return v
}

fn print_line_mode(headers []string, rows [][]string) {
	for row in rows {
		for i, cell in row {
			println('${headers[i]} = ${cell}')
		}
		println('')
	}
}

fn print_column(headers []string, rows [][]string, color bool) {
	widths := compute_widths(headers, rows)
	println(join_cells(headers, widths, ' ', color))
	for row in rows {
		println(join_cells(row, widths, ' ', false))
	}
}

fn print_table(headers []string, rows [][]string, unicode bool) {
	widths := compute_widths(headers, rows)
	chars := if unicode {
		TableChars{
			h:  '─'
			v:  '│'
			tl: '┌'
			tr: '┐'
			bl: '└'
			br: '┘'
			tc: '┬'
			bc: '┴'
			lc: '├'
			rc: '┤'
			cc: '┼'
		}
	} else {
		TableChars{
			h:  '-'
			v:  '|'
			tl: '+'
			tr: '+'
			bl: '+'
			br: '+'
			tc: '+'
			bc: '+'
			lc: '+'
			rc: '+'
			cc: '+'
		}
	}
	println(table_border(widths, chars.tl, chars.tc, chars.tr, chars.h))
	println('${chars.v} ${join_cells(headers, widths, chars.v, true)} ${chars.v}')
	println(table_border(widths, chars.lc, chars.cc, chars.rc, chars.h))
	for row in rows {
		println('${chars.v} ${join_cells(row, widths, chars.v, false)} ${chars.v}')
	}
	println(table_border(widths, chars.bl, chars.bc, chars.br, chars.h))
}

struct TableChars {
	h  string
	v  string
	tl string
	tr string
	bl string
	br string
	tc string
	bc string
	lc string
	rc string
	cc string
}

fn table_border(widths []int, left string, center string, right string, h string) string {
	mut b := strings.new_builder(64)
	b.write_string(left)
	for i, w in widths {
		b.write_string(h.repeat(w + 2))
		if i < widths.len - 1 {
			b.write_string(center)
		}
	}
	b.write_string(right)
	return b.str()
}

fn compute_widths(headers []string, rows [][]string) []int {
	mut widths := headers.map(it.len)
	for row in rows {
		for i, cell in row {
			if i >= widths.len {
				widths << cell.len
				continue
			}
			if cell.len > widths[i] {
				widths[i] = cell.len
			}
		}
	}
	return widths
}

fn join_cells(values []string, widths []int, sep string, color bool) string {
	mut out := []string{cap: values.len}
	for i, v in values {
		cell := v + ' '.repeat(widths[i] - v.len)
		out << if color { term.bright_cyan(cell) } else { cell }
	}
	return out.join(' ${sep} ')
}

fn print_json(headers []string, rows [][]string, lines bool) {
	if lines {
		for row in rows {
			println(row_as_json(headers, row))
		}
		return
	}
	println('[')
	for i, row in rows {
		suffix := if i < rows.len - 1 { ',' } else { '' }
		println('  ${row_as_json(headers, row)}${suffix}')
	}
	println(']')
}

fn row_as_json(headers []string, row []string) string {
	mut parts := []string{cap: row.len}
	for i, cell in row {
		parts << '"${json_escape(headers[i])}":"${json_escape(cell)}"'
	}
	return '{' + parts.join(',') + '}'
}

fn json_escape(v string) string {
	return v.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n')
}

fn value_to_text(v ladybug.Value) string {
	if v.is_null() {
		return 'NULL'
	}
	if x := v.int64() {
		return x.str()
	}
	if x := v.uint64() {
		return x.str()
	}
	if x := v.int32() {
		return x.str()
	}
	if x := v.double() {
		return '${x:.6f}'.trim_right('0').trim_right('.')
	}
	if x := v.float() {
		return '${x:.6f}'.trim_right('0').trim_right('.')
	}
	if x := v.bool() {
		return if x { 'true' } else { 'false' }
	}
	if x := v.string() {
		return x
	}
	if x := v.internal_id_text() {
		return x
	}
	return '<value>'
}

fn statement_complete(s string) bool {
	mut in_single := false
	mut in_double := false
	mut in_line_comment := false
	mut in_block_comment := false
	mut i := 0
	for i < s.len {
		c := s[i]
		next := if i + 1 < s.len { s[i + 1] } else { u8(0) }
		match true {
			in_line_comment {
				if c == `\n` {
					in_line_comment = false
				}
			}
			in_block_comment {
				if c == `*` && next == `/` {
					in_block_comment = false
					i++
				}
			}
			in_single {
				if c == `'` {
					in_single = false
				}
			}
			in_double {
				if c == `"` {
					in_double = false
				}
			}
			else {
				if c == `/` && next == `/` {
					in_line_comment = true
					i++
				} else if c == `/` && next == `*` {
					in_block_comment = true
					i++
				} else if c == `'` {
					in_single = true
				} else if c == `"` {
					in_double = true
				} else if c == `;` {
					return true
				}
			}
		}
		i++
	}
	return s.starts_with('.')
}

fn should_refresh_catalog(query string) bool {
	upper := query.trim_space().to_upper()
	for prefix in create_prefixes {
		if upper.starts_with(prefix) {
			return true
		}
	}
	return false
}

fn (mut s Shell) load_history() ! {
	if s.history_file.len == 0 {
		return
	}
	os.mkdir_all(os.dir(s.history_file)) or {}
	if !os.exists(s.history_file) {
		os.write_file(s.history_file, '')!
		return
	}
	content := os.read_file(s.history_file) or { return }
	for raw in content.split_into_lines() {
		line := raw.trim_space()
		if line.len == 0 {
			continue
		}
		s.r.previous_lines.insert(1, line.runes())
		s.last_history = line
	}
}

fn (mut s Shell) append_history(line string) {
	if s.history_file.len == 0 || line == s.last_history {
		return
	}
	mut f := os.open_append(s.history_file) or { return }
	defer {
		f.close()
	}
	f.write_string('${line}\n') or { return }
	s.last_history = line
}

fn (c &CompletionEngine) complete(prefix string) []string {
	if prefix.len == 0 {
		mut all := []string{}
		all << c.table_names
		all << c.property_names
		all << cypher_keywords
		return build_completion_options('', '', all)
	}
	base, token := split_completion_input(prefix)
	trimmed := prefix.trim_space()
	if trimmed.starts_with('.') {
		mut commands := []string{}
		for cmd in shell_commands {
			if starts_with_ci(cmd, token) {
				commands << cmd
			}
		}
		return commands
	}
	kw := legal_keyword_candidates(prefix)
	context := completion_context(base, token)
	if context == .table_name {
		scope := table_lookup_scope(base, token)
		candidates := match scope {
			.node { c.node_table_names }
			.rel { c.rel_table_names }
			.any { c.table_names }
		}
		return build_completion_options(base, token, candidates)
	}
	if context == .property_name {
		return build_completion_options(base, token, c.property_names)
	}
	mut all := []string{}
	all << kw
	if should_suggest_tables(base, token) {
		all << c.table_names
	}
	if should_suggest_properties(base, token) {
		all << c.property_names
	}
	all << cypher_keywords
	return build_completion_options(base, token, all)
}

fn split_completion_input(input string) (string, string) {
	mut i := input.len - 1
	for i >= 0 {
		c := input[i]
		if c.is_letter() || c.is_digit() || c == `_` || c == `.` || c == `:` {
			i--
			continue
		}
		break
	}
	start := i + 1
	if start < 0 {
		return '', input
	}
	return input[..start], input[start..]
}

fn build_completion_options(base string, token string, candidates []string) []string {
	token_prefix, token_filter := completion_token_context(token)
	mut seen := map[string]bool{}
	mut out := []string{}
	for raw in candidates {
		candidate := raw.trim_space()
		if candidate.len == 0 {
			continue
		}
		if token_filter.len > 0 && !starts_with_ci(candidate, token_filter) {
			continue
		}
		full := base + token_prefix + candidate
		if full in seen {
			continue
		}
		seen[full] = true
		out << full
	}
	return out
}

fn completion_token_context(token string) (string, string) {
	last_colon := token.last_index(':') or { -1 }
	last_dot := token.last_index('.') or { -1 }
	last_sep := if last_colon > last_dot { last_colon } else { last_dot }
	if last_sep < 0 {
		return '', token
	}
	return token[..last_sep + 1], token[last_sep + 1..]
}

fn completion_context(base string, token string) CompletionContext {
	last_colon := token.last_index(':') or { -1 }
	last_dot := token.last_index('.') or { -1 }
	if last_colon > last_dot {
		return .table_name
	}
	if last_dot > last_colon {
		return .property_name
	}
	trimmed_base := base.trim_right(' \t')
	if trimmed_base.ends_with(':') {
		return .table_name
	}
	if trimmed_base.ends_with('.') {
		return .property_name
	}
	return .normal
}

fn table_lookup_scope(base string, token string) TableLookupScope {
	mut ctx := base + token
	mut colon_pos := -1
	last_colon := token.last_index(':') or { -1 }
	if last_colon >= 0 {
		colon_pos = base.len + last_colon
	} else {
		trimmed := ctx.trim_right(' \t')
		if trimmed.ends_with(':') {
			ctx = trimmed
			colon_pos = ctx.len - 1
		}
	}
	if colon_pos <= 0 || colon_pos > ctx.len - 1 {
		return .any
	}
	mut i := colon_pos - 1
	for i >= 0 {
		c := ctx[i]
		if c == `[` {
			return .rel
		}
		if c == `(` {
			return .node
		}
		if c == `]` || c == `)` {
			break
		}
		i--
	}
	return .any
}

fn starts_with_ci(s string, p string) bool {
	return s.to_upper().starts_with(p.to_upper())
}

fn legal_keyword_candidates(prefix string) []string {
	words := tokenize_words(prefix.to_upper())
	if words.len == 0 {
		return [
			'MATCH ',
			'CREATE ',
			'MERGE ',
			'CALL ',
			'RETURN ',
			'DROP ',
		]
	}
	last := words[words.len - 1]
	return match last {
		'CREATE' {
			['NODE ', 'REL ', 'GRAPH ', 'TABLE ']
		}
		'DROP' {
			['TABLE ', 'GRAPH ', 'NODE ', 'REL ']
		}
		'MATCH', 'MERGE' {
			['WHERE ', 'RETURN ', 'CREATE ', 'SET ', 'WITH ']
		}
		'RETURN' {
			['LIMIT ', 'ORDER BY ', 'SKIP ']
		}
		'CALL' {
			['SHOW_TABLES()', 'TABLE_INFO(', 'CURRENT_SETTING(']
		}
		'FROM', 'TO', 'TABLE', 'GRAPH' {
			[]string{}
		}
		else {
			['WHERE ', 'RETURN ', 'WITH ', 'SET ', 'MATCH ', 'CREATE ']
		}
	}
}

fn should_suggest_tables(base string, token string) bool {
	upper_ctx := (base + token).to_upper()
	upper_base := base.to_upper()
	upper_token := token.to_upper()
	return upper_token.contains(':') || upper_ctx.contains(':') || upper_base.ends_with(' FROM ')
		|| upper_base.ends_with(' TO ') || upper_base.ends_with(' TABLE ')
		|| upper_base.ends_with(' GRAPH ') || upper_base.ends_with('MATCH (')
		|| upper_base.ends_with('MERGE (')
}

fn should_suggest_properties(base string, token string) bool {
	upper_ctx := (base + token).to_upper()
	upper_base := base.to_upper()
	return token.ends_with('.') || token.contains('.') || upper_base.contains(' RETURN ')
		|| upper_base.contains(' WHERE ') || upper_base.contains(' SET ')
		|| upper_base.contains(' ORDER BY ') || upper_ctx.ends_with('.')
}

fn tokenize_words(text string) []string {
	mut out := []string{}
	mut start := -1
	for i := 0; i < text.len; i++ {
		c := text[i]
		if c.is_letter() || c == `_` {
			if start == -1 {
				start = i
			}
		} else if start != -1 {
			out << text[start..i]
			start = -1
		}
	}
	if start != -1 {
		out << text[start..]
	}
	return out
}

fn (mut s Shell) refresh_completion_catalog() {
	mut table_names := []string{}
	mut node_table_names := []string{}
	mut rel_table_names := []string{}
	mut property_names := []string{}
	mut seen_tables := map[string]bool{}
	mut seen_node_tables := map[string]bool{}
	mut seen_rel_tables := map[string]bool{}
	mut seen_props := map[string]bool{}
	mut tables_result := s.conn.query('CALL show_tables() RETURN *;') or { return }
	headers := tables_result.column_names() or { []string{} }
	name_idx := headers.index('name')
	type_idx := table_type_index(headers)
	for tables_result.has_next() {
		mut tuple := tables_result.next_tuple() or { break }
		if name_idx >= 0 {
			mut value := tuple.value(u64(name_idx)) or {
				tuple.close()
				continue
			}
			table_name := value_to_text(value).trim_space()
			value.close()
			mut table_type := lbug_unknown_table_type
			if type_idx >= 0 {
				mut type_value := tuple.value(u64(type_idx)) or {
					tuple.close()
					continue
				}
				table_type = value_to_text(type_value).trim_space().to_upper()
				type_value.close()
			}
			if table_name.len > 0 && table_name !in seen_tables {
				table_names << table_name
				seen_tables[table_name] = true
				if table_type.contains('NODE') && table_name !in seen_node_tables {
					node_table_names << table_name
					seen_node_tables[table_name] = true
				}
				if table_type.contains('REL') && table_name !in seen_rel_tables {
					rel_table_names << table_name
					seen_rel_tables[table_name] = true
				}
				s.collect_table_properties(table_name, mut property_names, mut seen_props)
			}
		}
		tuple.close()
	}
	tables_result.close()
	s.completion.table_names = table_names
	s.completion.node_table_names = if node_table_names.len > 0 {
		node_table_names
	} else {
		table_names
	}
	s.completion.rel_table_names = if rel_table_names.len > 0 {
		rel_table_names
	} else {
		table_names
	}
	s.completion.property_names = property_names
}

const lbug_unknown_table_type = '<UNKNOWN>'

fn table_type_index(headers []string) int {
	for name in ['type', 'table_type', 'tabletype', 'kind', 'table_kind', 'entity_type'] {
		idx := headers.index(name)
		if idx >= 0 {
			return idx
		}
	}
	return -1
}

fn (s &Shell) collect_table_properties(table_name string, mut out []string, mut seen map[string]bool) {
	safe_name := table_name.replace("'", "''")
	query_text := "CALL table_info('${safe_name}') RETURN *;"
	mut info := s.conn.query(query_text) or { return }
	defer {
		info.close()
	}
	headers := info.column_names() or { []string{} }
	name_idx := headers.index('name')
	if name_idx < 0 {
		return
	}
	for info.has_next() {
		mut tuple := info.next_tuple() or { break }
		mut value := tuple.value(u64(name_idx)) or {
			tuple.close()
			continue
		}
		prop := value_to_text(value).trim_space()
		value.close()
		if prop.len > 0 && prop !in seen {
			seen[prop] = true
			out << prop
		}
		tuple.close()
	}
}
