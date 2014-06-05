#!/usr/bin/perl

use Dancer;
use DBI;
use File::Spec;
use File::Slurp;
use Template;
use Data::Dumper;

use Dancer::Logger::Console;

 
set 'database'     => File::Spec->catfile(File::Spec->curdir(), 'dancr.db');
set 'session'      => 'Simple';
set 'template'     => 'template_toolkit';
set 'logger'       => 'console';
set 'log'          => 'debug';
set 'show_errors'  => 1;
set 'startup_info' => 1;
set 'warnings'     => 1;
set 'username'     => 'admin';
set 'password'     => 'password';
set 'layout'       => 'main';

 
my $flash;
my $id_of_post;
my $logger = Dancer::Logger::Console->new;

my $post_pe_pages = 4;

sub get_numbers_of_pages {
	my $search = shift;
	my $db = connect_db();
	my $sql2 = '';
	
	if ($search) {
		$sql2 = 'select count(id) from entries where title like ?';
		my $sth2 = $db->prepare($sql2) or die $db->errstr;
		$sth2->execute("%$search%") or die $sth2->errstr;
		my @rc = $sth2->fetchrow_array;
		$logger->debug("\n\n All news : $rc[0] | Numbers of pages: " . int($rc[0] / $post_pe_pages) );
		return int( $rc[0] / $post_pe_pages);
	} else {
		$sql2 = 'select count(id) from entries ';
		my $sth2 = $db->prepare($sql2) or die $db->errstr;
		$sth2->execute or die $sth2->errstr;
		my @rc = $sth2->fetchrow_array;
		$logger->debug("\n\n All news : $rc[0] | Numbers of pages: " . int($rc[0] / $post_pe_pages) );
		return int( $rc[0] / $post_pe_pages);
		}
	
}

sub set_flash {
	my $message = shift;

	$flash = $message;
}
 
sub get_flash {
	my $msg = $flash;
	$flash = "";

	return $msg;
}
 
sub connect_db {
	my $dbh = DBI->connect("dbi:SQLite:dbname=".setting('database')) or
		   die $DBI::errstr;

	return $dbh;
}
 
sub init_db {
	#create database file if he no exist
	system( 'sqlite3 dancr.db < schema.sql' ) if ( !(m/dancr\.db/ =~ `ls`) );
	my $db = connect_db();
	my $schema = read_file('./schema.sql');
	$db->do($schema) or die $db->errstr;
}

#show page of posts
sub show_page{
	my $page = shift;
	my $db = connect_db();
	my $sql = 'select id, title, text, entries.date_post, count(entries_id) as count 
		from entries 
			left join comments on id = entries_id 
			group by id 
			order by id desc limit 4 offset ' . ($page * 4);
    my $sth = $db->prepare($sql) or die $db->errstr;
    $sth->execute or die $sth->errstr;
    #$logger->debug(Dumper $sth->fetchall_arrayref());
       template 'show_entries.tt', {
		       'cur_state' => 1,
			   'cur_page' => $page || 0,
			   'nb_of_pg' => get_numbers_of_pages(),
               'msg' => get_flash(),
               'add_entry_url' => uri_for('/add'),
               'search_engine' => uri_for('/search/0/'),
               'entries' => $sth->fetchall_arrayref(),
               'domen' => request->uri_base,
               'numbers' => [ $page > 1 ? $page - 1 : 0, $page + 1 ]
	};
};

sub show_post{
	$id_of_post = shift;
	my $db = connect_db();
	
	my $sql = 'select id, title, text_all from entries where id = ?';
    my $sth = $db->prepare($sql) or die $db->errstr;
    $sth->execute($id_of_post) or die $sth->errstr;
    
    my $sql_show_comments = 'select author, comment, date_post from comments where entries_id = ?';
    my $sth_show_comments = $db->prepare($sql_show_comments) or die $db->errstr;
    $sth_show_comments->execute($id_of_post) or die $sth->errstr;
 
	template 'show_post.tt', {
		'cur_state' => 1,
		'msg' => get_flash(),
		'nb_of_pg' => get_numbers_of_pages(),
		'add_comment_url' => uri_for('/add_comment'),
		'search_engine' => uri_for('/search/0/'),
		'entries' => $sth->fetchrow_hashref(),
		'comments' => $sth_show_comments->fetchall_arrayref(),
		'domen' => request->uri_base,
	};
};

sub search{
	my ($search_string, $page) = @_;
	my $db = connect_db();
	#$logger->debug("\nSearch string and page " . $search_string . $page . "\n");
	
	my $sql = 'select id, title, text, entries.date_post, count(entries_id) as count 
		from entries 
			left join comments on id = entries_id
			where title like ? 
			group by id
			order by id desc limit 4 offset ' . ($page * 4);
	$logger->debug("\n\n" . $sql . "\n\n");
    my $sth = $db->prepare($sql) or die $db->errstr;
    $sth->execute("%$search_string%") or die $sth->errstr;
    #$logger->debug('%' . $search_string . '%');
    my $prev_page = $page > 1 ? $page - 1 : 0;
    my $next_page = $page + 1;
    $logger->debug("\n Numbers of pages: " . get_numbers_of_pages($search_string));
    #$logger->debug( request->uri_for("/search/$next_page/", { search => params->{'search'} }) );
    #$logger->debug(Dumper $sth->fetchall_arrayref());
       template 'search_entries.tt', {
		       'cur_state' => 1,
			   'cur_page' => $page || 0,
			   'nb_of_pg' => get_numbers_of_pages($search_string),
               'msg' => get_flash(),
               'add_entry_url' => uri_for('/add'),
               'search_engine' => uri_for('/search/0/'),
               'entries' => $sth->fetchall_arrayref(),
               'domen' => request->uri_base,
               'prev_page' => request->uri_for("/search/$prev_page/", { search => params->{'search'} }),
               'next_page' => request->uri_for("/search/$next_page/", { search => params->{'search'} })
	};
	
};

sub update_post{
	$id_of_post = shift;
	my $db = connect_db();
	
	my $sql = 'select id, title, text, text_all from entries where id = ?';
    my $sth = $db->prepare($sql) or die $db->errstr;
    $sth->execute($id_of_post) or die $sth->errstr;
    
    #$logger->debug(Dumper $sth->fetchrow_hashref());
    template 'add_post.tt', {
		'cur_state' => 1,
		'add_post' => uri_for('/update'),
		'post' => $sth->fetchrow_hashref()
	};
};

sub delete_item {
	my $id = shift;
	my $db = connect_db();
	
	my $sql_comments = 'delete from comments where entries_id = ?';
	my $sth_comments = $db->prepare($sql_comments) or die $db->errstr;
	$sth_comments->execute($id) or die $sth_comments->errstr;
	
	my $sql = 'delete from entries where id = ?';
	my $sth = $db->prepare($sql) or die $db->errstr;
	$sth->execute($id) or die $sth->errstr;
	redirect '/';
};


hook before_template => sub {
	my $tokens = shift;

	$tokens->{'css_url'} = request->base . 'css/style.css';
	$tokens->{'login_url'} = uri_for('/login');
	$tokens->{'logout_url'} = uri_for('/logout');
	$tokens->{'domen'} = request->uri_base;
};
 
get '/' => sub {
	show_page(0);
};


 ####### General route #########
get '/*/*/' => sub {
	my ($action, $id) = splat;
	if ($action eq 'page') {
		return show_page($id);
	} elsif ($action eq 'view') {
		return show_post($id);
	} elsif ($action eq 'delete') {
		return delete_item($id);
	} elsif ($action eq 'update') {
		return update_post($id);
	} elsif ($action eq 'search') {
		return search(params->{'search'}, $id ||= 0 );
	} else {
		status 'not_found';
		return "What?";
	}
};


get '/add_post' => sub {
	template 'add_post.tt', {
		'add_post' => uri_for('/add')
	};
}; 
 


post '/add' => sub {
	if ( not session('logged_in') ) {
		   send_error("Not logged in", 401);
	}

	my $db = connect_db();
	my $sql = "insert into entries (title, text, text_all, date_post) values (?, ?, ?, datetime('now'))";
	my $sth = $db->prepare($sql) or die $db->errstr;
	$sth->execute(params->{'title'}, params->{'text'}, params->{'text_all'}) or die $sth->errstr;

	#set_flash('New entry posted!');
	redirect '/';
};

post '/update' => sub {
	if ( not session('logged_in') ) {
		   send_error("Not logged in", 401);
	}
	
	my $db = connect_db();
	my $sql = "update entries set  title = ?, text = ?, text_all = ?, date_post = datetime('now') where id = $id_of_post";
	my $sth = $db->prepare($sql) or die $db->errstr;
	$sth->execute(params->{'title'}, params->{'text'}, params->{'text_all'}) or die $sth->errstr;

	#set_flash('New entry posted!');
	redirect '/';
};

post '/add_comment' => sub {
	
	my $db = connect_db();
	my $sql = "insert into comments (entries_id, author, comment, date_post) values (?, ?, ?, datetime('now'))";
	my $sth = $db->prepare($sql) or die $db->errstr;
	$sth->execute($id_of_post, params->{'author'}, params->{'text'}) or die $sth->errstr;

	#set_flash('New entry posted!');
	redirect "/view/$id_of_post/";
};

any ['get', 'post'] => '/login' => sub {
	my $err;

	if ( request->method() eq "POST" ) {
		   # process form input
		   if ( params->{'username'} ne setting('username') ) {
				   $err = "Invalid username";
		   }
		   elsif ( params->{'password'} ne setting('password') ) {
				   $err = "Invalid password";
		   }
		   else {
				   session 'logged_in' => true;
				   return redirect '/';
		   }
	}

	
 
};
 
get '/logout' => sub {
	session->destroy;
	redirect '/';
};

get qr{/hi/([\w]+)} => sub {
	my ($name) = splat;
	return "Hello $name";
};
 
get '/hello/:name' => sub {
	"Hello there ".param('name').", welcome here!";
}; 

get '/batman' => sub {
	return request->uri_base . request->uri;
};

get '/abba' => sub {
	return request->path;
};

get '/bob' => sub {
	template 'show_entries.tt';
};

init_db();
start;
