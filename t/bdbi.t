#!/usr/bin/perl

use strict;
use Test::More;

BEGIN {
	eval { require DBD::Pg; };
	plan skip_all => 'needs DBD::Pg for testing' if $@;
	eval { require Class::DBI; };
}

use lib 'lib';
use base 'Fry::Lib::CDBI::BDBI';
#needed for dang parse_num
use base 'Fry::Shell';
use lib 't/testlib/';
use base 'Bmark';

eval {__PACKAGE__->create_temp_table};
plan skip_all=>"table setup failed: $@" if $@;
plan tests=>2;


#global var
	#my @columns = (qw/id cmd tags options notes/);

#bdbi
	#test setdb passes
	#eval {__PACKAGE__->setdb({pwd=>'',qw/tb t_bmark db postgres user bozo dbname useful/,db_opts=>{AutoCommit=>1}})};
	#ok(! $@,"&setdb executes fine");

	#tb set
	#is(__PACKAGE__->table,'t_bmark','table() set correct');

	#&db_columns
	eval {__PACKAGE__->db_columns('postgres',__PACKAGE__->table)};
	ok(! $@, "&db_columns didn't die");

	#printcols=cols
	is_deeply(__PACKAGE__->printcols,__PACKAGE__->cols,'cols() eq printcols()');

	#getcol_*() returned correctly to cols() 
	#TODO: didn't work on my server
	#is_deeply([sort  __PACKAGE__->columns],[sort@{__PACKAGE__->cols}],'cols() defined correctly by &getcol_*');
