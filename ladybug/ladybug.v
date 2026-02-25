module ladybug

#flag -I @VMODROOT/ladybug
#flag darwin -L @VMODROOT/lib -llbug -Wl,-rpath,@VMODROOT/lib -Wl,-rpath,@loader_path/../lib -Wl,-rpath,@executable_path/../lib
#flag linux -L @VMODROOT/lib -llbug -Wl,-rpath,@VMODROOT/lib -Wl,-rpath,$ORIGIN/../lib
#flag windows -L @VMODROOT/lib -llbug
#include "lbug.h"

@[typedef]
struct C.lbug_system_config {
	buffer_pool_size     u64
	max_num_threads      u64
	enable_compression   bool
	read_only            bool
	max_db_size          u64
	auto_checkpoint      bool
	checkpoint_threshold u64
	thread_qos           u32
}

@[typedef]
struct C.lbug_database {
	_database voidptr
}

@[typedef]
struct C.lbug_connection {
	_connection voidptr
}

@[typedef]
struct C.lbug_prepared_statement {
	_prepared_statement voidptr
	_bound_values       voidptr
}

@[typedef]
struct C.lbug_query_result {
	_query_result    voidptr
	_is_owned_by_cpp bool
}

@[typedef]
struct C.lbug_flat_tuple {
	_flat_tuple      voidptr
	_is_owned_by_cpp bool
}

@[typedef]
struct C.lbug_logical_type {
	_data_type voidptr
}

@[typedef]
struct C.lbug_value {
	_value           voidptr
	_is_owned_by_cpp bool
}

@[typedef]
struct C.lbug_query_summary {
	_query_summary voidptr
}

@[typedef]
struct C.lbug_internal_id_t {
	table_id u64
	offset   u64
}

@[typedef]
struct C.lbug_date_t {
	days i32
}

@[typedef]
struct C.lbug_timestamp_t {
	value i64
}

@[typedef]
struct C.lbug_timestamp_ns_t {
	value i64
}

@[typedef]
struct C.lbug_timestamp_ms_t {
	value i64
}

@[typedef]
struct C.lbug_timestamp_sec_t {
	value i64
}

@[typedef]
struct C.lbug_timestamp_tz_t {
	value i64
}

@[typedef]
struct C.lbug_interval_t {
	months i32
	days   i32
	micros i64
}

@[typedef]
struct C.lbug_int128_t {
	low  u64
	high i64
}

// Core C API declarations used by high-level wrappers.
fn C.lbug_default_system_config() C.lbug_system_config
fn C.lbug_database_init(database_path &char, system_config C.lbug_system_config, out_database &C.lbug_database) int
fn C.lbug_database_destroy(database &C.lbug_database)
fn C.lbug_connection_init(database &C.lbug_database, out_connection &C.lbug_connection) int
fn C.lbug_connection_destroy(connection &C.lbug_connection)
fn C.lbug_connection_set_max_num_thread_for_exec(connection &C.lbug_connection, num_threads u64) int
fn C.lbug_connection_get_max_num_thread_for_exec(connection &C.lbug_connection, out_result &u64) int
fn C.lbug_connection_query(connection &C.lbug_connection, query &char, out_query_result &C.lbug_query_result) int
fn C.lbug_connection_prepare(connection &C.lbug_connection, query &char, out_prepared_statement &C.lbug_prepared_statement) int
fn C.lbug_connection_execute(connection &C.lbug_connection, prepared_statement &C.lbug_prepared_statement, out_query_result &C.lbug_query_result) int
fn C.lbug_connection_interrupt(connection &C.lbug_connection)
fn C.lbug_connection_set_query_timeout(connection &C.lbug_connection, timeout_in_ms u64) int

fn C.lbug_prepared_statement_destroy(prepared_statement &C.lbug_prepared_statement)
fn C.lbug_prepared_statement_is_success(prepared_statement &C.lbug_prepared_statement) bool
fn C.lbug_prepared_statement_get_error_message(prepared_statement &C.lbug_prepared_statement) &char
fn C.lbug_prepared_statement_bind_bool(prepared_statement &C.lbug_prepared_statement, param_name &char, value bool) int
fn C.lbug_prepared_statement_bind_int64(prepared_statement &C.lbug_prepared_statement, param_name &char, value i64) int
fn C.lbug_prepared_statement_bind_int32(prepared_statement &C.lbug_prepared_statement, param_name &char, value i32) int
fn C.lbug_prepared_statement_bind_double(prepared_statement &C.lbug_prepared_statement, param_name &char, value f64) int
fn C.lbug_prepared_statement_bind_float(prepared_statement &C.lbug_prepared_statement, param_name &char, value f32) int
fn C.lbug_prepared_statement_bind_string(prepared_statement &C.lbug_prepared_statement, param_name &char, value &char) int
fn C.lbug_prepared_statement_bind_value(prepared_statement &C.lbug_prepared_statement, param_name &char, value &C.lbug_value) int

fn C.lbug_query_result_destroy(query_result &C.lbug_query_result)
fn C.lbug_query_result_is_success(query_result &C.lbug_query_result) bool
fn C.lbug_query_result_get_error_message(query_result &C.lbug_query_result) &char
fn C.lbug_query_result_get_num_columns(query_result &C.lbug_query_result) u64
fn C.lbug_query_result_get_column_name(query_result &C.lbug_query_result, index u64, out_column_name &&char) int
fn C.lbug_query_result_get_num_tuples(query_result &C.lbug_query_result) u64
fn C.lbug_query_result_get_query_summary(query_result &C.lbug_query_result, out_query_summary &C.lbug_query_summary) int
fn C.lbug_query_result_has_next(query_result &C.lbug_query_result) bool
fn C.lbug_query_result_get_next(query_result &C.lbug_query_result, out_flat_tuple &C.lbug_flat_tuple) int
fn C.lbug_query_result_reset_iterator(query_result &C.lbug_query_result)

fn C.lbug_flat_tuple_destroy(flat_tuple &C.lbug_flat_tuple)
fn C.lbug_flat_tuple_get_value(flat_tuple &C.lbug_flat_tuple, index u64, out_value &C.lbug_value) int

fn C.lbug_value_destroy(value &C.lbug_value)
fn C.lbug_value_is_null(value &C.lbug_value) bool
fn C.lbug_value_get_bool(value &C.lbug_value, out_result &bool) int
fn C.lbug_value_get_int64(value &C.lbug_value, out_result &i64) int
fn C.lbug_value_get_int32(value &C.lbug_value, out_result &i32) int
fn C.lbug_value_get_double(value &C.lbug_value, out_result &f64) int
fn C.lbug_value_get_float(value &C.lbug_value, out_result &f32) int
fn C.lbug_value_get_string(value &C.lbug_value, out_result &&char) int

fn C.lbug_query_summary_destroy(query_summary &C.lbug_query_summary)
fn C.lbug_query_summary_get_compiling_time(query_summary &C.lbug_query_summary) f64
fn C.lbug_query_summary_get_execution_time(query_summary &C.lbug_query_summary) f64

fn C.lbug_get_version() &char
fn C.lbug_get_storage_version() u64
fn C.lbug_destroy_string(str &char)

const lbug_success = 0

pub struct SystemConfig {
pub mut:
	buffer_pool_size     u64
	max_num_threads      u64
	enable_compression   bool
	read_only            bool
	max_db_size          u64
	auto_checkpoint      bool
	checkpoint_threshold u64
	thread_qos           u32
}

fn (c SystemConfig) to_c() C.lbug_system_config {
	mut raw := C.lbug_default_system_config()
	raw.buffer_pool_size = c.buffer_pool_size
	raw.max_num_threads = c.max_num_threads
	raw.enable_compression = c.enable_compression
	raw.read_only = c.read_only
	raw.max_db_size = c.max_db_size
	raw.auto_checkpoint = c.auto_checkpoint
	raw.checkpoint_threshold = c.checkpoint_threshold
	raw.thread_qos = c.thread_qos
	return raw
}

pub fn default_system_config() SystemConfig {
	raw := C.lbug_default_system_config()
	return SystemConfig{
		buffer_pool_size:     raw.buffer_pool_size
		max_num_threads:      raw.max_num_threads
		enable_compression:   raw.enable_compression
		read_only:            raw.read_only
		max_db_size:          raw.max_db_size
		auto_checkpoint:      raw.auto_checkpoint
		checkpoint_threshold: raw.checkpoint_threshold
		thread_qos:           raw.thread_qos
	}
}

pub struct Database {
mut:
	raw    C.lbug_database
	closed bool
pub:
	path string
}

pub fn open_database(path string, config SystemConfig) !Database {
	mut db := Database{
		path: path
	}
	state := C.lbug_database_init(path.str, config.to_c(), &db.raw)
	if state != lbug_success {
		return error('failed to open database: ${path}')
	}
	return db
}

pub fn (mut db Database) close() {
	if db.closed {
		return
	}
	C.lbug_database_destroy(&db.raw)
	db.closed = true
}

pub struct Connection {
mut:
	raw    C.lbug_connection
	closed bool
}

pub fn connect(mut db Database) !Connection {
	mut conn := Connection{}
	state := C.lbug_connection_init(&db.raw, &conn.raw)
	if state != lbug_success {
		return error('failed to connect to database')
	}
	return conn
}

pub fn (mut conn Connection) close() {
	if conn.closed {
		return
	}
	C.lbug_connection_destroy(&conn.raw)
	conn.closed = true
}

pub fn (mut conn Connection) set_max_threads(num_threads u64) ! {
	state := C.lbug_connection_set_max_num_thread_for_exec(&conn.raw, num_threads)
	if state != lbug_success {
		return error('failed to set max threads')
	}
}

pub fn (conn &Connection) max_threads() !u64 {
	mut out := u64(0)
	state := C.lbug_connection_get_max_num_thread_for_exec(&conn.raw, &out)
	if state != lbug_success {
		return error('failed to read max threads')
	}
	return out
}

pub fn (mut conn Connection) set_timeout(timeout_ms u64) ! {
	state := C.lbug_connection_set_query_timeout(&conn.raw, timeout_ms)
	if state != lbug_success {
		return error('failed to set timeout')
	}
}

pub fn (conn &Connection) interrupt() {
	C.lbug_connection_interrupt(&conn.raw)
}

pub struct PreparedStatement {
mut:
	raw    C.lbug_prepared_statement
	closed bool
pub:
	query string
}

pub fn (conn &Connection) prepare(query string) !PreparedStatement {
	mut stmt := PreparedStatement{
		query: query
	}
	state := C.lbug_connection_prepare(&conn.raw, query.str, &stmt.raw)
	if state != lbug_success {
		msg := stmt.error_message()
		if msg.len > 0 {
			return error(msg)
		}
		return error('failed to prepare query')
	}
	if !stmt.is_success() {
		return error(stmt.error_message())
	}
	return stmt
}

pub fn (mut stmt PreparedStatement) close() {
	if stmt.closed {
		return
	}
	C.lbug_prepared_statement_destroy(&stmt.raw)
	stmt.closed = true
}

pub fn (stmt &PreparedStatement) is_success() bool {
	return C.lbug_prepared_statement_is_success(&stmt.raw)
}

pub fn (stmt &PreparedStatement) error_message() string {
	msg := C.lbug_prepared_statement_get_error_message(&stmt.raw)
	if msg == unsafe { nil } {
		return ''
	}
	text := unsafe { cstring_to_vstring(msg) }
	C.lbug_destroy_string(msg)
	return text
}

fn bind_state_err(state int, param_name string) ! {
	if state != lbug_success {
		return error('failed to bind parameter "${param_name}"')
	}
}

pub fn (mut stmt PreparedStatement) bind_bool(param_name string, value bool) ! {
	bind_state_err(C.lbug_prepared_statement_bind_bool(&stmt.raw, param_name.str, value),
		param_name)!
}

pub fn (mut stmt PreparedStatement) bind_int64(param_name string, value i64) ! {
	bind_state_err(C.lbug_prepared_statement_bind_int64(&stmt.raw, param_name.str, value),
		param_name)!
}

pub fn (mut stmt PreparedStatement) bind_int32(param_name string, value i32) ! {
	bind_state_err(C.lbug_prepared_statement_bind_int32(&stmt.raw, param_name.str, value),
		param_name)!
}

pub fn (mut stmt PreparedStatement) bind_double(param_name string, value f64) ! {
	bind_state_err(C.lbug_prepared_statement_bind_double(&stmt.raw, param_name.str, value),
		param_name)!
}

pub fn (mut stmt PreparedStatement) bind_float(param_name string, value f32) ! {
	bind_state_err(C.lbug_prepared_statement_bind_float(&stmt.raw, param_name.str, value),
		param_name)!
}

pub fn (mut stmt PreparedStatement) bind_string(param_name string, value string) ! {
	bind_state_err(C.lbug_prepared_statement_bind_string(&stmt.raw, param_name.str, value.str),
		param_name)!
}

pub fn (mut stmt PreparedStatement) bind_value(param_name string, value &Value) ! {
	bind_state_err(C.lbug_prepared_statement_bind_value(&stmt.raw, param_name.str, value.cptr()),
		param_name)!
}

pub struct QueryResult {
mut:
	raw    C.lbug_query_result
	closed bool
}

pub fn (conn &Connection) query(query string) !QueryResult {
	mut result := QueryResult{}
	state := C.lbug_connection_query(&conn.raw, query.str, &result.raw)
	if state != lbug_success {
		msg := result.error_message()
		if msg.len > 0 {
			return error(msg)
		}
		return error('query failed')
	}
	if !result.is_success() {
		return error(result.error_message())
	}
	return result
}

pub fn (conn &Connection) execute(stmt &PreparedStatement) !QueryResult {
	mut result := QueryResult{}
	state := C.lbug_connection_execute(&conn.raw, unsafe { &stmt.raw }, &result.raw)
	if state != lbug_success {
		msg := result.error_message()
		if msg.len > 0 {
			return error(msg)
		}
		return error('failed to execute prepared statement')
	}
	if !result.is_success() {
		return error(result.error_message())
	}
	return result
}

pub fn (mut result QueryResult) close() {
	if result.closed {
		return
	}
	C.lbug_query_result_destroy(&result.raw)
	result.closed = true
}

pub fn (result &QueryResult) is_success() bool {
	return C.lbug_query_result_is_success(&result.raw)
}

pub fn (result &QueryResult) error_message() string {
	msg := C.lbug_query_result_get_error_message(&result.raw)
	if msg == unsafe { nil } {
		return ''
	}
	text := unsafe { cstring_to_vstring(msg) }
	C.lbug_destroy_string(msg)
	return text
}

pub fn (result &QueryResult) num_columns() u64 {
	return C.lbug_query_result_get_num_columns(&result.raw)
}

pub fn (result &QueryResult) num_rows() u64 {
	return C.lbug_query_result_get_num_tuples(&result.raw)
}

pub fn (result &QueryResult) column_names() ![]string {
	count := result.num_columns()
	mut names := []string{cap: int(count)}
	for i in u64(0) .. count {
		mut out := &char(unsafe { nil })
		state := C.lbug_query_result_get_column_name(&result.raw, i, &out)
		if state != lbug_success {
			return error('failed to get column name at index ${i}')
		}
		name := unsafe { cstring_to_vstring(out) }
		C.lbug_destroy_string(out)
		names << name
	}
	return names
}

pub fn (result &QueryResult) has_next() bool {
	return C.lbug_query_result_has_next(&result.raw)
}

pub fn (result &QueryResult) next_tuple() !FlatTuple {
	mut tuple := FlatTuple{}
	state := C.lbug_query_result_get_next(&result.raw, &tuple.raw)
	if state != lbug_success {
		return error('failed to read next tuple')
	}
	return tuple
}

pub fn (result &QueryResult) reset_iterator() {
	C.lbug_query_result_reset_iterator(&result.raw)
}

pub fn (result &QueryResult) summary() !QuerySummary {
	mut summary := QuerySummary{}
	state := C.lbug_query_result_get_query_summary(&result.raw, &summary.raw)
	if state != lbug_success {
		return error('failed to get query summary')
	}
	return summary
}

pub struct FlatTuple {
mut:
	raw    C.lbug_flat_tuple
	closed bool
}

pub fn (mut tuple FlatTuple) close() {
	if tuple.closed {
		return
	}
	C.lbug_flat_tuple_destroy(&tuple.raw)
	tuple.closed = true
}

pub fn (tuple &FlatTuple) value(index u64) !Value {
	mut raw_value := C.lbug_value{}
	state := C.lbug_flat_tuple_get_value(&tuple.raw, index, &raw_value)
	if state != lbug_success {
		return error('failed to get value at index ${index}')
	}
	return Value{
		raw: raw_value
	}
}

pub struct Value {
mut:
	raw      C.lbug_value
	ptr      &C.lbug_value = unsafe { nil }
	uses_ptr bool
	closed   bool
}

fn (value &Value) cptr() &C.lbug_value {
	if value.uses_ptr {
		return value.ptr
	}
	return unsafe { &value.raw }
}

pub fn (mut value Value) close() {
	if value.closed {
		return
	}
	C.lbug_value_destroy(value.cptr())
	value.closed = true
}

pub fn (value &Value) is_null() bool {
	return C.lbug_value_is_null(value.cptr())
}

pub fn (value &Value) bool() !bool {
	mut out := false
	state := C.lbug_value_get_bool(value.cptr(), &out)
	if state != lbug_success {
		return error('value is not BOOL')
	}
	return out
}

pub fn (value &Value) int64() !i64 {
	mut out := i64(0)
	state := C.lbug_value_get_int64(value.cptr(), &out)
	if state != lbug_success {
		return error('value is not INT64')
	}
	return out
}

pub fn (value &Value) int32() !i32 {
	mut out := i32(0)
	state := C.lbug_value_get_int32(value.cptr(), &out)
	if state != lbug_success {
		return error('value is not INT32')
	}
	return out
}

pub fn (value &Value) double() !f64 {
	mut out := f64(0)
	state := C.lbug_value_get_double(value.cptr(), &out)
	if state != lbug_success {
		return error('value is not DOUBLE')
	}
	return out
}

pub fn (value &Value) float() !f32 {
	mut out := f32(0)
	state := C.lbug_value_get_float(value.cptr(), &out)
	if state != lbug_success {
		return error('value is not FLOAT')
	}
	return out
}

pub fn (value &Value) string() !string {
	mut out := &char(unsafe { nil })
	state := C.lbug_value_get_string(value.cptr(), &out)
	if state != lbug_success {
		return error('value is not STRING')
	}
	text := unsafe { cstring_to_vstring(out) }
	C.lbug_destroy_string(out)
	return text
}

pub fn create_null_value() !Value {
	ptr := C.lbug_value_create_null()
	if ptr == unsafe { nil } {
		return error('failed to create null value')
	}
	return Value{
		ptr:      ptr
		uses_ptr: true
	}
}

pub fn create_bool_value(v bool) !Value {
	ptr := C.lbug_value_create_bool(v)
	if ptr == unsafe { nil } {
		return error('failed to create bool value')
	}
	return Value{
		ptr:      ptr
		uses_ptr: true
	}
}

pub fn create_int64_value(v i64) !Value {
	ptr := C.lbug_value_create_int64(v)
	if ptr == unsafe { nil } {
		return error('failed to create int64 value')
	}
	return Value{
		ptr:      ptr
		uses_ptr: true
	}
}

pub fn create_int32_value(v i32) !Value {
	ptr := C.lbug_value_create_int32(v)
	if ptr == unsafe { nil } {
		return error('failed to create int32 value')
	}
	return Value{
		ptr:      ptr
		uses_ptr: true
	}
}

pub fn create_double_value(v f64) !Value {
	ptr := C.lbug_value_create_double(v)
	if ptr == unsafe { nil } {
		return error('failed to create double value')
	}
	return Value{
		ptr:      ptr
		uses_ptr: true
	}
}

pub fn create_float_value(v f32) !Value {
	ptr := C.lbug_value_create_float(v)
	if ptr == unsafe { nil } {
		return error('failed to create float value')
	}
	return Value{
		ptr:      ptr
		uses_ptr: true
	}
}

pub fn create_string_value(v string) !Value {
	ptr := C.lbug_value_create_string(v.str)
	if ptr == unsafe { nil } {
		return error('failed to create string value')
	}
	return Value{
		ptr:      ptr
		uses_ptr: true
	}
}

pub struct QuerySummary {
mut:
	raw    C.lbug_query_summary
	closed bool
}

pub fn (mut summary QuerySummary) close() {
	if summary.closed {
		return
	}
	C.lbug_query_summary_destroy(&summary.raw)
	summary.closed = true
}

pub fn (summary &QuerySummary) compiling_time_ms() f64 {
	return C.lbug_query_summary_get_compiling_time(&summary.raw)
}

pub fn (summary &QuerySummary) execution_time_ms() f64 {
	return C.lbug_query_summary_get_execution_time(&summary.raw)
}

pub fn version() string {
	ptr := C.lbug_get_version()
	if ptr == unsafe { nil } {
		return ''
	}
	return unsafe { cstring_to_vstring(ptr) }
}

pub fn storage_version() u64 {
	return C.lbug_get_storage_version()
}

// Additional C API declarations for value creation used by wrappers above.
fn C.lbug_value_create_null() &C.lbug_value
fn C.lbug_value_create_bool(v bool) &C.lbug_value
fn C.lbug_value_create_int64(v i64) &C.lbug_value
fn C.lbug_value_create_int32(v i32) &C.lbug_value
fn C.lbug_value_create_float(v f32) &C.lbug_value
fn C.lbug_value_create_double(v f64) &C.lbug_value
fn C.lbug_value_create_string(v &char) &C.lbug_value
