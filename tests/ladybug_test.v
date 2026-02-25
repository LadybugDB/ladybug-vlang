import ladybug
import os
import time

fn has_liblbug() bool {
	$if macos {
		return os.exists(os.join_path(os.getwd(), 'lib', 'liblbug.dylib'))
	}
	$if linux {
		return os.exists(os.join_path(os.getwd(), 'lib', 'liblbug.so'))
	}
	$if windows {
		return os.exists(os.join_path(os.getwd(), 'lib', 'liblbug.dll'))
	}
	return false
}

fn new_db_path(prefix string) string {
	base := os.join_path(os.temp_dir(), 'ladybug_vlang_tests')
	os.mkdir_all(base) or {}
	return os.join_path(base, '${prefix}_${time.now().unix_milli()}')
}

fn cleanup_db(path string) {
	os.rmdir_all(path) or { os.rm(path) or {} }
}

fn open_conn(prefix string) !(string, ladybug.Database, ladybug.Connection) {
	path := new_db_path(prefix)
	config := ladybug.default_system_config()
	mut db := ladybug.open_database(path, config)!
	mut conn := ladybug.connect(mut db)!
	return path, db, conn
}

fn seed_people(mut conn ladybug.Connection) ! {
	mut r1 := conn.query('CREATE NODE TABLE IF NOT EXISTS Person(name STRING, age INT64, PRIMARY KEY(name))')!
	r1.close()
	mut r2 := conn.query("MERGE (p:Person {name: 'Alice'}) SET p.age = 30")!
	r2.close()
	mut r3 := conn.query("MERGE (p:Person {name: 'Bob'}) SET p.age = 25")!
	r3.close()
	mut r4 := conn.query("MERGE (p:Person {name: 'Cara'}) SET p.age = 40")!
	r4.close()
}

fn test_01_version_not_empty() {
	if !has_liblbug() {
		return
	}
	assert ladybug.version().len > 0
}

fn test_02_storage_version_positive() {
	if !has_liblbug() {
		return
	}
	assert ladybug.storage_version() > 0
}

fn test_03_default_config_smoke() {
	config := ladybug.default_system_config()
	assert config.max_num_threads >= 0
	assert config.checkpoint_threshold >= 0
}

fn test_04_open_close_database() {
	if !has_liblbug() {
		return
	}
	path := new_db_path('open_close')
	mut db := ladybug.open_database(path, ladybug.default_system_config()) or { panic(err) }
	db.close()
	cleanup_db(path)
}

fn test_05_connect_disconnect() {
	if !has_liblbug() {
		return
	}
	path, mut db, mut conn := open_conn('connect_disconnect') or { panic(err) }
	conn.close()
	db.close()
	cleanup_db(path)
}

fn test_06_create_table_query_success() {
	if !has_liblbug() {
		return
	}
	path, mut db, mut conn := open_conn('create_table') or { panic(err) }
	mut res := conn.query('CREATE NODE TABLE Person(name STRING, age INT64, PRIMARY KEY(name))') or {
		panic(err)
	}
	assert res.is_success()
	res.close()
	conn.close()
	db.close()
	cleanup_db(path)
}

fn test_07_merge_is_idempotent() {
	if !has_liblbug() {
		return
	}
	path, mut db, mut conn := open_conn('merge_idempotent') or { panic(err) }
	seed_people(mut conn) or { panic(err) }
	mut r := conn.query("MERGE (p:Person {name: 'Alice'}) SET p.age = 30") or { panic(err) }
	r.close()
	mut q := conn.query("MATCH (p:Person) WHERE p.name = 'Alice' RETURN COUNT(*)") or { panic(err) }
	mut t := q.next_tuple() or { panic(err) }
	mut v := t.value(0) or { panic(err) }
	assert v.int64() or { panic(err) } == 1
	v.close()
	t.close()
	q.close()
	conn.close()
	db.close()
	cleanup_db(path)
}

fn test_08_column_metadata() {
	if !has_liblbug() {
		return
	}
	path, mut db, mut conn := open_conn('column_metadata') or { panic(err) }
	seed_people(mut conn) or { panic(err) }
	mut q := conn.query('MATCH (p:Person) RETURN p.name, p.age') or { panic(err) }
	names := q.column_names() or { panic(err) }
	assert names.len == 2
	assert names[0] == 'p.name'
	assert names[1] == 'p.age'
	q.close()
	conn.close()
	db.close()
	cleanup_db(path)
}

fn test_09_num_rows_and_columns() {
	if !has_liblbug() {
		return
	}
	path, mut db, mut conn := open_conn('rows_cols') or { panic(err) }
	seed_people(mut conn) or { panic(err) }
	mut q := conn.query('MATCH (p:Person) RETURN p.name, p.age') or { panic(err) }
	assert q.num_rows() == 3
	assert q.num_columns() == 2
	q.close()
	conn.close()
	db.close()
	cleanup_db(path)
}

fn test_10_tuple_string_and_int64() {
	if !has_liblbug() {
		return
	}
	path, mut db, mut conn := open_conn('tuple_values') or { panic(err) }
	seed_people(mut conn) or { panic(err) }
	mut q := conn.query("MATCH (p:Person) WHERE p.name = 'Alice' RETURN p.name, p.age") or {
		panic(err)
	}
	mut t := q.next_tuple() or { panic(err) }
	mut name := t.value(0) or { panic(err) }
	mut age := t.value(1) or { panic(err) }
	assert name.string() or { panic(err) } == 'Alice'
	assert age.int64() or { panic(err) } == 30
	name.close()
	age.close()
	t.close()
	q.close()
	conn.close()
	db.close()
	cleanup_db(path)
}

fn test_11_reset_iterator() {
	if !has_liblbug() {
		return
	}
	path, mut db, mut conn := open_conn('reset_iterator') or { panic(err) }
	seed_people(mut conn) or { panic(err) }
	mut q := conn.query('MATCH (p:Person) RETURN p.name ORDER BY p.name') or { panic(err) }
	assert q.has_next()
	mut t1 := q.next_tuple() or { panic(err) }
	mut n1 := t1.value(0) or { panic(err) }
	first := n1.string() or { panic(err) }
	n1.close()
	t1.close()
	q.reset_iterator()
	mut t2 := q.next_tuple() or { panic(err) }
	mut n2 := t2.value(0) or { panic(err) }
	assert n2.string() or { panic(err) } == first
	n2.close()
	t2.close()
	q.close()
	conn.close()
	db.close()
	cleanup_db(path)
}

fn test_12_query_summary_available() {
	if !has_liblbug() {
		return
	}
	path, mut db, mut conn := open_conn('query_summary') or { panic(err) }
	seed_people(mut conn) or { panic(err) }
	mut q := conn.query('MATCH (p:Person) RETURN p.name') or { panic(err) }
	mut s := q.summary() or { panic(err) }
	assert s.compiling_time_ms() >= 0
	assert s.execution_time_ms() >= 0
	s.close()
	q.close()
	conn.close()
	db.close()
	cleanup_db(path)
}

fn test_13_prepare_success() {
	if !has_liblbug() {
		return
	}
	path, mut db, mut conn := open_conn('prepare_success') or { panic(err) }
	seed_people(mut conn) or { panic(err) }
	mut stmt := conn.prepare('MATCH (p:Person) WHERE p.age > ' + r'$min_age' + ' RETURN p.name') or {
		panic(err)
	}
	assert stmt.is_success()
	stmt.close()
	conn.close()
	db.close()
	cleanup_db(path)
}

fn test_14_prepare_error_message_nonempty() {
	if !has_liblbug() {
		return
	}
	path, mut db, mut conn := open_conn('prepare_error') or { panic(err) }
	conn.prepare('MATCH INVALID QUERY') or {
		assert '${err}'.len > 0
		conn.close()
		db.close()
		cleanup_db(path)
		return
	}
	assert false
	conn.close()
	db.close()
	cleanup_db(path)
}

fn test_15_execute_prepared_with_int64_bind() {
	if !has_liblbug() {
		return
	}
	path, mut db, mut conn := open_conn('execute_prepared') or { panic(err) }
	seed_people(mut conn) or { panic(err) }
	mut stmt := conn.prepare('MATCH (p:Person) WHERE p.age > ' + r'$min_age' +
		' RETURN p.name ORDER BY p.name') or { panic(err) }
	stmt.bind_int64('min_age', 29) or { panic(err) }
	mut q := conn.execute(&stmt) or { panic(err) }
	assert q.num_rows() == 2
	q.close()
	stmt.close()
	conn.close()
	db.close()
	cleanup_db(path)
}

fn test_16_set_get_max_threads() {
	if !has_liblbug() {
		return
	}
	path, mut db, mut conn := open_conn('threads') or { panic(err) }
	conn.set_max_threads(2) or { panic(err) }
	threads := conn.max_threads() or { panic(err) }
	assert threads >= 1
	conn.close()
	db.close()
	cleanup_db(path)
}

fn test_17_set_timeout() {
	if !has_liblbug() {
		return
	}
	path, mut db, mut conn := open_conn('timeout') or { panic(err) }
	conn.set_timeout(5000) or { panic(err) }
	conn.close()
	db.close()
	cleanup_db(path)
}

fn test_18_value_create_string_roundtrip() {
	if !has_liblbug() {
		return
	}
	mut v := ladybug.create_string_value('hello') or { panic(err) }
	assert v.string() or { panic(err) } == 'hello'
	v.close()
}

fn test_19_value_create_int64_roundtrip() {
	if !has_liblbug() {
		return
	}
	mut v := ladybug.create_int64_value(42) or { panic(err) }
	assert v.int64() or { panic(err) } == 42
	v.close()
}

fn test_20_value_create_bool_roundtrip() {
	if !has_liblbug() {
		return
	}
	mut v := ladybug.create_bool_value(true) or { panic(err) }
	assert v.bool() or { panic(err) }
	v.close()
}

fn test_21_bind_string_prepared() {
	if !has_liblbug() {
		return
	}
	path, mut db, mut conn := open_conn('bind_string') or { panic(err) }
	seed_people(mut conn) or { panic(err) }
	mut stmt := conn.prepare('MATCH (p:Person) WHERE p.name = ' + r'$name' + ' RETURN p.age') or {
		panic(err)
	}
	stmt.bind_string('name', 'Bob') or { panic(err) }
	mut q := conn.execute(&stmt) or { panic(err) }
	mut t := q.next_tuple() or { panic(err) }
	mut age := t.value(0) or { panic(err) }
	assert age.int64() or { panic(err) } == 25
	age.close()
	t.close()
	q.close()
	stmt.close()
	conn.close()
	db.close()
	cleanup_db(path)
}

fn test_22_query_error_propagates() {
	if !has_liblbug() {
		return
	}
	path, mut db, mut conn := open_conn('query_error') or { panic(err) }
	conn.query('MATCH (p Person RETURN p') or {
		assert '${err}'.len > 0
		conn.close()
		db.close()
		cleanup_db(path)
		return
	}
	assert false
	conn.close()
	db.close()
	cleanup_db(path)
}
