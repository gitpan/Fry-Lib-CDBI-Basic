package Fry::Lib::CDBI::BDBI;
	use strict qw/subs vars/;
	use base 'Class::Data::Global';
	our @ISA;
	
#methods
	sub _default_data {
		return {
			global=>{
				qw/user nobody
				pwd blah
				db postgres
				dbname template1/,
				tb=>'',
				cols=>'',
				printcols=>'',
				db_opts=>{AutoCommit=>1},
				_db_default=>{
					postgres=>{
						regex=>'~',
					},	
					mysql=>{
						regex=>'REGEXP',
					},
					sqlite=>{
					},

				}	
			},
		}	
	}	
	sub setdb {
		#d: alternative to &Class::DBI::set_db
		my $class = shift;
		die "only one argument for &setdb" if (@_ >1);
		my $hashref = shift;
		my %db_driver = (qw/mysql dbi:mysql: postgres dbi:Pg:dbname= sqlite
			dbi:SQLite:dbname=/);

		#write new global values
		#$class->setmany(%$hashref) ifp (defined %$hashref);
		$class->set_or_mk_global(%$hashref) if (defined %$hashref);
		
		#to make rest of code easier to read
		our ($pwd,$user,$db,$dbname,$tb,$options) =
		$class->getmany(qw/pwd user db dbname tb db_opts/);

		#note: select still works without primary_sequence
		if ($db eq "postgres") {
			require Class::DBI::Pg;
			push (@ISA,'Class::DBI::Pg');

			__PACKAGE__->set_db('Main',$db_driver{$db}.$dbname,$user,$pwd,$options);
			__PACKAGE__->set_up_table($tb);
		}
		elsif ($db eq "sqlite") {
			require Class::DBI::SQLite;
			push (@ISA,'Class::DBI::SQLite');

			__PACKAGE__->set_db('Main', $db_driver{$db}.$dbname,$user,$pwd,$options);
			__PACKAGE__->set_up_table($tb);
		}
		elsif ($db eq "mysql")  {
			require Class::DBI;
			push (@ISA,'Class::DBI');

			__PACKAGE__->set_db('Main',$db_driver{$db}.$dbname,$user,$pwd,$options);
			__PACKAGE__->table($tb);
			my @columns = __PACKAGE__->getcol_mysql;
			__PACKAGE__->columns(All=>@columns);
			__PACKAGE__->set_or_mk_global(cols=>\@columns);
		}
		else { die "your database $db isn't supported"}  

		#any initializations w/ up2date var
		$class->db_columns($db,$tb);
		#$class->add_constraint('nospace',filename=>\&check_song);
	} 
	sub db_columns { 
		#d: initializes column data dependent &columns
		my ($class,$database,$table) = @_;

		#set &cols
			my $method = "getcol_$database";

			#if method exists to get dependable ordering of columns for database
			if ($class->can($method)) {
				$class->set_or_mk_global(cols=>[$class->$method($table)]);
			}	
			#fall back on defined columns from Class::DBI, whose order isn't dependable :(
			else {
				$class->set_or_mk_global(cols=>[$class->columns]);
			}	

		#sync &printcols with &cols
		$class->set_or_mk_global(printcols=>$class->cols);

		$class->set_insert_col;
	}
	sub search_regex { 
		my $class = shift;
		$class->_do_search($class->_db_default->{__PACKAGE__->db}{regex}=> @_);
	}

	#h: this should be in Basic but will have to wait till there's a defined function
	#that executes from library after loading data
	sub set_insert_col {
		my $class = shift;
		#set insertcol 
		my @insertcol = @{$class->cols};
		shift @insertcol;
		$class->mk_cdata_global(insertcol=>\@insertcol);

	}	
	#h: the rest of the functions have been copied from their Class::DBI::*
	#all the getcol does is return the columns of a table in order
	sub getcol_postgres {
		my ($class,$table) = @_;
		my @cols;
		eval {require DBD::Pg};

		my $catalog = ($class->pg_version >= 7.3) ? "pg_catalog." : "";
		my $sth = $class->db_Main->prepare("SELECT a.attname, a.attnum FROM ${catalog}pg_class c, ${catalog}pg_attribute a
	WHERE c.relname = ?  AND a.attnum > 0 AND a.attrelid = c.oid ORDER BY a.attnum");
		$sth->execute($table);
		my $columns = $sth->fetchall_arrayref;
		$sth->finish;

		foreach my $col(@$columns) {
			# skip dropped column.
			next if $col->[0] =~ /^\.+pg\.dropped\.\d+\.+$/;
			push @cols, $col->[0];
		}
		return @cols;
	}
	sub getcol_sqlite {
		my ($class,$table) = @_;
		my $sth = $class->db_Main->prepare("PRAGMA table_info(?)");
		$sth->execute($table);
		my @columns;
		while (my $row = $sth->fetchrow_hashref) {
			push @columns,$row->{name};
	    }
	    $sth->finish;
		return @columns;
	}
	sub getcol_mysql {
		#d:get columns of tb
		#t:mysql
		my $class = shift;
		my (@cols, @pri);

		$class->set_sql(desc_table => 'DESCRIBE __TABLE__');
		(my $sth = $class->sql_desc_table)->execute;

		while (my $hash = $sth->fetch_hash) {
			my ($col) = $hash->{field} =~ /(\w+)/;
			push @cols, $col;
			push @pri, $col if $hash->{key} eq "PRI";
		}
		#$class->_croak("$table has no primary key") unless @pri;
		return @cols
	}
	#used by getcol_postgres
	sub pg_version {
		my $class = shift;
		my $dbh = $class->db_Main;
		my $sth = $dbh->prepare("SELECT version()");
		$sth->execute;
		my($ver_str) = $sth->fetchrow_array;
		$sth->finish;
		my($ver) = $ver_str =~ m/^PostgreSQL ([\d\.]{3})/;
		return $ver;
	}
	1;

__END__	

=head1 NAME

CDBI::BDBI.pm - A subclass of Class::DBI containing several class data to be used by most Class::DBI
libraries.

=head1 NOTES

This module contains functions necessary to load other Class::DBI libraries.
The only necessary one when setting up a database connection is &db_columns.
See the samples directory for more detail.
An extra Class::DBI search function, &search_regex, is provided which
evidently searches with a regex operator (only for mysql and postgresql).  I
also temporarily copied methods that obtain a table's columns for
mysql,postgresql and sqlite from their Class::DBI::* extensions.

=head1 Class Methods

=over 4

=item B<setdb()>

=item B<setdb(\%options)>

This method is a wrapper around Class::DBI's &set_db, it's table and column declarations and
&db_columns. You can specify defaults for any of the below options in a library config file. That way when you
pass options to &setdb only the defaults are overidden.

%options can include any of the following as keys:

	user($): username
	pwd($): password
	dbname($):  database name
	db($): database management system
		choices are: mysql,postgres,sqlite
	tb($): table name
	cols(\@): column names
	db_opts(\%): options passed as hashref to Class::DBI's &set_db

		__PACKAGE__->setdb({tb=>'kings',db=>'mysql');

This method currently supports mysql,postgresql and sqllite.

=item B< db_columns($database,table) >

Sets the &cols accessor which keeps a table's columns in order (which seems to be a problem with
Class::DBI's &columns accessor). Afterwards, sets &printcols accessor which are columns to be
manipulated by user for display purposes usually. 

=back

=head1 Global data

Here's a brief list of this module's global data

	Note: datum with a * next to it must be defined for a Class::DBI library to work.

	user($): database user
	pwd($): database password
	db($): database management system (dbms) ie mysql,postgres,sqlite
	dbname($): database name	
	*tb($): table name
	*cols(\@): column names
	*printcols(\@): 
	db_opts(\%): options passed as hashref to Class::DBI's &set_db
	_db_default(\%): defaults specific to dbms

=head1	TO DO

This module will eventually incorporate loading tables via Class::DBI::Loader in order to switch
tables within the shell. 

An easier and more universal DBI or SQL way of obtaining a table's columns.

=head1 AUTHOR

Me. Gabriel that is. If you want to bug me with a bug: cldwalker@chwhat.com
If you like using perl,linux,vim and databases to make your life easier (not lazier ;) check out my website
at www.chwhat.com.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under the same terms as Perl
itself.
