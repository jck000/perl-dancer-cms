create table if not exists entries (
	id integer primary key autoincrement,
	title string not null,
	text string not null,
	text_all string not null,
	date_post string not null
);

create table if not exists comments (
	author string not null, 
	comment string not null,
	date_post string not null,
	entries_id integer,
	FOREIGN KEY(entries_id) REFERENCES entries(id)
);
