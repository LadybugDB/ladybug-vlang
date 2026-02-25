import ladybug

fn main() {
	main_impl() or { panic(err) }
}

fn main_impl() ! {
	config := ladybug.default_system_config()
	mut db := ladybug.open_database('test.db', config)!
	defer {
		db.close()
	}

	mut conn := ladybug.connect(mut db)!
	defer {
		conn.close()
	}

	mut result := conn.query('CREATE NODE TABLE IF NOT EXISTS Person(name STRING, age INT64, PRIMARY KEY(name))')!
	result.close()

	mut insert := conn.query("MERGE (p:Person {name: 'Alice'}) SET p.age = 30")!
	insert.close()

	mut q := conn.query('MATCH (p:Person) RETURN p.name, p.age')!
	defer {
		q.close()
	}

	println('ladybug version: ${ladybug.version()}')
	println('rows: ${q.num_rows()}, cols: ${q.num_columns()}')
	println('columns: ${(q.column_names()!).join(', ')}')

	for q.has_next() {
		mut tuple := q.next_tuple()!
		mut name_v := tuple.value(0)!
		mut age_v := tuple.value(1)!
		println('${name_v.string()!} is ${age_v.int64()!} years old')
		name_v.close()
		age_v.close()
		tuple.close()
	}
}
