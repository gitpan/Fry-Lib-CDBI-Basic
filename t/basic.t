#!/usr/bin/perl

use strict;
use Test::More;

BEGIN {
	eval { require DBD::Pg; };
	plan skip_all => 'needs DBD::Pg for testing' if $@;
}

use lib 'lib';
#needed for search_regex
use base 'Fry::Lib::CDBI::BDBI';
#needed for dang parse_num
use base 'Fry::Shell';
use lib 't/testlib';
use base 'Bmark';

#connects via Class::DBI,create temporary table and creates records
eval { __PACKAGE__->db_setup; };
plan skip_all=>"table setup failed: $@" if $@;

plan tests=>16;

#var
	my $basic = "Fry::Lib::CDBI::Basic";
	our (@ISA);

#fns
	sub modify_file {
		require Tie::File;
		my $class = shift;
		my @lines;

		tie @lines,'Tie::File',$_[0] or die "Tie failed: $@";
		for (@lines) { s/cool/sweet/g };
		untie @lines;

		return 1;
	}

#pretesting
	#define variables normally defined via shell ie db,tb,dbname
	__PACKAGE__->mk_many_global(%{Fry::Lib::CDBI::BDBI->_default_data->{global}});
	__PACKAGE__->mk_many_global('_flag'=>{},insertcol=>[qw/url tags notes name/],_fh=>'STDOUT');
	__PACKAGE__->mk_many_global(db=>'postgres',dbname=>$PgBase::db,tb=>__PACKAGE__->table,cols=>\@Bmark::columns
		,printcols=>\@Bmark::columns);

#testing
	eval {require Fry::Lib::CDBI::Basic; push (@ISA,$basic);};
	ok (! $@,"$basic loaded fine");
		#load more class data
		__PACKAGE__->mk_many_global(%{$basic->_default_data->{global}});
		__PACKAGE__->_default_search('search_regex');
		$basic->_init_lib;

	#cdi_select: returns correct obj from search_like
		#inputalias+col2f1
		my @aliased = __PACKAGE__->inputalias(qw/c2=yay c5=db/);
		is("@aliased","name=yay notes=db","&inputalias works");

		#parselect
		my %parsehash = __PACKAGE__->parseselect(__PACKAGE__->_splitter,qw/test=yep once=again/); 	
		is_deeply({qw/test yep once again/},\%parsehash,"&parseselect");
		
		#determine splitter for rest of tests
		eval {require Class::DBI::AbstractSearch};
		__PACKAGE__->_default_splitter('=') if ($@);

		my @obj = __PACKAGE__->get_select(qw/tags=perl/);
		ok($obj[0]->isa('Class::DBI'),'checking if obj returns + is Class::DBI');	
		
		eval{__PACKAGE__->cdbi_select(qw/c4=salsa/)};	
		ok (! $@,"&cdbi_select runs");

	#cdbi_insert
		my $insert_arg = "somesite.com,,cool,,blah,,blah";
		my %inserthash = __PACKAGE__->parseinsert($insert_arg);
		is_deeply({qw/url somesite.com tags cool notes blah name blah/},\%inserthash,'&parseinsert parses');

		__PACKAGE__->cdbi_insert($insert_arg);
		eval{__PACKAGE__->cdbi_insert($insert_arg)};
		ok (! $@,"&cdbi_insert runs");
		#if greater 
		is(__PACKAGE__->search(qw/url somesite.com/),2,'verify inserted row exists');
	#replace
		__PACKAGE__->printcols([qw/name notes/]);
		eval {__PACKAGE__->replace(qw/url=somesite.com s#blah#bling#/)};  
		ok (! $@,"&replace runs");

		__PACKAGE__->printcols(__PACKAGE__->cols);
		my (@temprow) =__PACKAGE__->search(qw/url somesite.com/);
		is($temprow[0]->notes,"bling",'result 1 notes field substituted correctly');
		is($temprow[1]->notes,"bling",'result 2 name field substituted correctly');
		
	#cdbi_update
	SKIP: {
		eval{ require Tie::File };
		skip "Tie::File not installed",3 if ($@);
		eval {__PACKAGE__->cdbi_update("url=somesite.com")};
		ok (! $@,"&cdbi_update runs");

		#verify updates made
		my @update_results = __PACKAGE__->search(qw/url somesite.com/);
		is ($update_results[0]->tags,'sweet','first row correctly updated');	
		is ($update_results[1]->tags,'sweet','second row correctly updated');	
	}
		
	#cdbi_delete
		eval {__PACKAGE__->cdbi_delete("url=somesite.com")};
		ok (! $@,"&cdbi_delete runs");
		print $@;
		is(__PACKAGE__->search(qw/url somesite.com/),0,'verify deleted row doesn\'t exist');
		
