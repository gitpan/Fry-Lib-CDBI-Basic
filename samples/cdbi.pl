#!/usr/bin/perl

package MyShell;
use strict;
our %o;
use Getopt::Long;

Getopt::Long::Configure ("bundling");
GetOptions(\%o,qw/m|menu d|db:s D|dbname:s t|table:s V|Version:i/);

use base 'Fry::Shell';

#main	
	#set shell prompt
	my $prompt = "cdbi_shell: ";

	__PACKAGE__->sh_init(prompt=>$prompt,option_value=>\%o,load_libs=>[qw/CDBI::Basic/],
		global=>{db=>'sqlite',dbname=>'/home/bozo/bin/temp/litedb',tb=>'bmark'});
		#declare user and password
		#user=>'me',pwd=>'top secret'});
		#add this to explicitly declare columns
		#cols=>[qw/ column1 column2 column3 ... /]

	#easy way to set up a cdbi connection, db defaults 
	__PACKAGE__->setdb;

	#explicit way of setting up cdbi connection

	#use base 'Class::DBI';
	#__PACKAGE__->set_db('Main','dbi:SQLite:dbname='.__PACKAGE__->dbname,__PACKAGE__->user,__PACKAGE__->pwd,{AutoCommit=>});
	#__PACKAGE__->db_columns(__PACKAGE__->db,__PACKAGE__->tb);
	#__PACKAGE__->table(__PACKAGE__->tb);
	#__PACKAGE__->columns(All => @{__PACKAGE__->cols});
	#__PACKAGE__->sequence(__PACKAGE__->tb.'_'.__PACKAGE__->cols->[0].'_seq');

	#begin shell loop
	__PACKAGE__->main_loop(@ARGV);
	
__END__	

=head1 NAME

cdbi.pl - Tutorial on setting up Class::DBI with its libraries.

=head1 DESCRIPTION 

Setting up a database connection for Class::DBI libraries is flexible and in theory should work with
any databases supported by Class::DBI.  I've verified the Class::DBI libraries to work with Mysql,
Postgresql and Sqlite.  If you have Postgresql and Class::DBI::Pg or Sqlite and Class::DBI::SQLite
or Mysql then you can use &Fry::Lib::CDBI::BDBI::setdb. If not, then you can set up your connection
in the script. 

=head1 Set Up	

To set up a Class::DBI connecton you need to do three things: 
1. Define database accessors to be used by Class::DBI libraries. They are listed under
the Global Data section of Fry::Lib::CDBI::BDBI. 
2. Do the normal Class::DBI setup: defining table,columns, and calling &set_db.
3. Call &db_columns for setting up a few more database accessors.

When setting an accessor in step 1, you should
be aware of the order of precedence in setting an accessor:

	option > script > library config file > library defaults > global config file

	See the Section 'Global Data' in Fry::Shell for more.

Let's override the defaults at the script level. To do this we use the global parameter in &sh_init.
If you look at this script's &sh_init call, you'll see an example. It redefines the application
database (db), database name (dbname), and table (tb). You can get this
example working fairly easily if you have sqlite. A sample sqlite database is provided in samples/.
Note that dbname is set to a file name. This is only true for sqlite since a database is identified
by a filename.

Steps 2 and 3 are done automagically by &setdb. However, if your database isn't currently
supported by &setdb or you have your own Class::DBI subclass you prefer, then you need to explicitly
do steps two and three. The commented out section below &setdb is an example. 

Currently, &set_db, &db_columns and &columns should be called in this order since &db_columns needs
a working database connection to define accessor &cols (which is used by &columns).

=head1 AUTHOR

Me. Gabriel that is.  I welcome feedback and bug reports to cldwalker AT chwhat DOT com .  If you
like using perl,linux,vim and databases to make your life easier (not lazier ;) check out my website
at www.chwhat.com.


=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under the same terms as Perl
itself.
