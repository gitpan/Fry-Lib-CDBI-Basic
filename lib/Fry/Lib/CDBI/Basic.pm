#!/usr/bin/perl
#importing
package Fry::Lib::CDBI::Basic;
	use base 'Class::Data::Global';
	use strict qw/vars refs/; #?forget the subs cause makes hash assignment a pain
	our $VERSION='0.05';
#variables
	#global
	#private	
	my $sql_count;

#functions
	sub _init_lib {
		my $class = shift;

		$class->_flag->{safe_update} = 1;

		my $abstract_operator = (exists $class->_db_default->{$class->db}->{regex}) ?
		$class->_db_default->{$class->db}->{regex} : "like";
		$class->_abstract_opts->{cmp} = $abstract_operator;
	}	
	sub _default_data {
		my $class = shift;
		
		return {
			depend=>['CDBI::BDBI'],
			global=>{
				_print_mode=>'n',
				_editor=>$ENV{EDITOR},
				_default_splitter=>'===',
				_splitter=>'=',
				_abstract_opts=>{logic=>'and'},
				_alias_print=> {qw/n print2darr t print_text_table/},
				_delim=>{tag=>',',display=>',,',insert=>',,'},
				_default_search=>'search_like',
				#_pager=>$ENV{PAGER},
			},	
			alias=>{
				cmds=>{	
					qw/s cdbi_select i cdbi_insert U cdbi_update d cdbi_delete
					pc printcol r replace :x execute :s display_obj :U update_obj
					\sl set_dbi_log_level \cl clear_dbi_log \pl print_dbi_log
					:d delete_obj V verify_no_delim/,
				},
				subs=>{qw/c setcol/},
				vars=>{ qw/t tb d db D dbname P _print_mode/},
				flags=>{qw/j join S safe_update/}
			},
			help=>{
				printcol=>{d=>'prints the columns of the current table',u=>''},
				set_db_log_level=>
					{d=>'sets the log level of DBI handle',u=>'$number'},
				print_dbi_log=>{d=>'prints the current DBI log',u=>''},
				clear_dbi_log=>{d=>'clears the dbi log',u=>''},
				cdbi_insert=>
					{d=>'inserts record',u=>'($value$delimiter)+'},
				cdbi_select=> {d=>'prints results of a query',
					u=>'($column$splitter<$operator>$column_value)+'},
				cdbi_delete=> {d=>'deletes results of given query',
					u=>'($column$splitter<$operator>$column_value)+'},
				cdbi_update=>{d=>'updates records via a text editor',
					u=>'($column$splitter<$operator>$column_value)+'},
				replace=>{d=>'evals each value of each result row with $operation',
					u=>'($column$splitter<$operator>$column_value)+ $operation'},
			}
		}	
	}	
	#note for library use outside of shell
	#this module depends on external subs: &parse_num

	#utils
	sub file2array {
		#local function
		#d:converts file to @ of lines
		open(FILE,"< $_[0]");
		my @lines; chomp(@lines = <FILE>);
		close FILE;
		return @lines;
	} 
	#internal functions
	sub setcol {
		my ($class,$choices) = @_;
		my @newcol = $class->parse_num($choices,@{$class->cols});

		#sets new columns
		$class->printcols(\@newcol);
	}
	sub check_for_regex {
		#d: could be used as an 'or' search on multiple columns
		my ($class,$regex,@records) = @_;
		my @unclean;

		for (@records) {
			for my $col (@{$class->printcols}) {
				if ($_->$col =~ /$regex/) {
					push(@unclean,$_);
					break;
				}	
			}		
		}	
		return @unclean;
	}
	sub modify_file {	
		my ($class,$tempfile) = @_;
		my $inp;

		system($class->_editor . " $tempfile");# or die "can't execute command as $<: $@";
		#?: why does this system always return a fail code
		print "cdbi_update (y/n)? "; chomp($inp = <STDIN>);
		return ($inp eq "y");
	}
	sub update_from_file {
		my ($class,$tempfile,@records) = @_;

		my @lines = file2array($tempfile);
		my $firstline = shift(@lines);
		#read column order from file
		#my @fields = split(/$updatedelim/,$firstline);
		#or not
		my @fields = @{$class->printcols};

		my $i;
		foreach (@records) {		#each row to update
			my @fvalues = split(/${\$class->_delim->{display}}/,$lines[$i]);
			for (my $j=0; $j < @fields; $j++) {		#each column to update

				my $temp=$fields[$j];
				$_->$temp($fvalues[$j]);		# this line = $_->$field($fieldvalue)
			}
			$_->update;
			#$_->dbi_commit if ($db = postgres
			$i++;
		}
	}
	sub col2f1 {
		#d: aliases column names with c and number
		my $class = shift;
		my @newterms;

		for (@_) { 
		#if (/c(\d+)=/) { my $col = $col[$1-1];s/c\d+/$col/} 
		if (/c([-,\d]+)(.*)/) { 
		my @tempcol = $class->parse_num($1,@{$class->cols});
			for my $eachcol (@tempcol) {  
				push(@newterms,$eachcol.$2);
			}
		}
		else {push (@newterms,$_)}
		}
		return @newterms;
	}
	#print functions,input is objects
	sub printtofile {
		#d:prints rows to temporary file
		my ($class,$tempfile,@records) =  @_;
		my $FH = "TEMP";
		no strict 'refs';	#due to filehandle TEMP

		#write to file
		open ($FH,"> $tempfile") or die "Couldn't open file: $@";
		print $FH join($class->_delim->{display},@{$class->printcols})."\n";
		$class->print2darr(\@records,$class->printcols,$FH);
		close TEMP;

		return $tempfile;
	} 
	sub print2darr { 
		#d: prints a two dimensional table with objects as rows and object attributes as columns
		#normal printing mode
		my $class = shift;
		my ($ref1,$ref2,$FH) = @_; my @row = @{$ref1}; my @columns = @{$ref2};
		my $i;
		no strict 'refs'; #due to TEMP symbol
		
		for (@row) {
			#h:
			if ($class->_flag->{menu}) {
				$i++; print $FH "$i: "
			}
			for my $column (@columns) {
				print $FH $_->$column;
				print $FH $class->_delim->{display};
			}
			print $FH "\n";
		}
	}
	sub print_text_table {
		my $class = shift;
		my ($ref1,$ref2,$FH) = @_; my @row = @{$ref1}; my @columns = @{$ref2};
		my (@column_values,@longest);

		#defaul
		eval { require Text::Reform}; die $@ if ($@);
		#if ($@) {$class->($mode,\@row,\@columns,$FH) }

		for my $column (@columns) {
			my @column_value;
			my $longest = length($column);
			for (@row) {
				#find longest string in each column including string
				my $newlength = length($_->$column);
				$longest = $newlength if ($newlength > $longest);

				push(@column_value,$_->$column);
			}
			push(@longest,$longest);
			push(@column_values,\@column_value);
		}	

		#create format
		my $line_length = 3 * @columns + 1; 
		my $picture_line = "|";

		for (@longest) { 
			$line_length += $_ ;
			$picture_line .= " " . "["x $_ . " |";
		}
		my $firstline = "=" x $line_length;
		#$picture_line .= "\n" . "-" x $line_length; 

		#print column names
		print form $picture_line,@columns;
		#print body
		print form $firstline,$picture_line, @column_values;
	}
	#parse functions,input is from commandine
	sub inputalias {
		my $class =  shift;
		@_ = $class->cols->[0].$class->_splitter.".*" if ($_[0] eq "a");  #all results given
		@_ = $class->col2f1(@_) if ("@_" =~ /c[-,\d]+=/);	#c\d instead of column name
		return @_;
	}
	sub parseinsert {
		#d:parses userinput to hashref for &create
		my $class = shift;
		my %chosenf;
		die "Nothing given for cdbi_insert" if (not defined @_);
		my @fields = split(/${\$class->_delim->{insert}}/,"@_");
		my @insertcol = @{$class->insertcol};

		for (my $i=0;$i< @insertcol;$i++) {
			$chosenf{$insertcol[$i]} = $fields[$i];
			print "$insertcol[$i] = $fields[$i]\n";
		}
		return %chosenf;
	} 
	sub input_to_abstract {
		#d:parse to feed to sql::abstract
		#note: operators hardcoded for now	
		my $class =  shift;
		my %processf;
		my $splitter = $class->_splitter;

		foreach (@_) {
			if (/$splitter([>!<])=/) {
				my $operator = $1;
				my ($key,$value) = split(/=$operator=/);
				$processf{$key} = {"$operator\=",$value};
			}	
			elsif (/$splitter([><=])/) {
				my $operator = $1;
				my ($key,$value) = split (/$splitter$operator/);
				$processf{$key} = {$operator,$value};
			}	
			#embedded sql
			elsif (/$splitter(.*)$splitter/) {
				my $literal_sql = $1;
				$literal_sql =~ s/_/ /g;
				my ($key,$dump) = split (/$splitter/);
				$processf{$key} = \$literal_sql;
			}	
			#default operator
			#elsif(/=/) {
			else {
				my ($key,$value) = split(/$splitter/) or die "error splitting select";
				$processf{$key} = $value;
			}	
			#else { warn "no valid operator specified" };	
		}
		return %processf;
	} 
	sub parseselect {
		#d:parses userinput to hashref for &search
		my ($class,$splitter,@chunks) =  @_;
		my %processf;

		for (@chunks) {
			my ($key,$value) = split(/$splitter/) or die "error splitting select";
			$processf{$key} = $value;
		}	
		return %processf;
	}	
	sub get_select {
		#d:handles multiple parsing cases and returns search results 
		my $class =  shift;
		my @results;

		eval {require Class::DBI::AbstractSearch};

		#abstractsearch plugin failed or default_search purposely chosen
		if ($@ or "@_" =~ /${\$class->_default_splitter}/) {

			my %chosenf  = $class->parseselect($class->_default_splitter,@_);
			@results =  $class->${\$class->_default_search}(%chosenf);
		}	
		else {
			my %chosenf = $class->input_to_abstract(@_);
			@results = $class->Class::DBI::AbstractSearch::search_where(\%chosenf,$class->_abstract_opts);
		}	
		return @results;
	} 
	#shell functions
	sub print_dbi_log {
		print shift->db_Main->{Profile}->format;
	}
	sub clear_dbi_log {
		shift->db_Main->{Profile}->{Data}=undef;
	}
	sub set_dbi_log_level{
		my ($class,$num) = @_;

		if ($num > 15 or $num < -15) {
			warn" given log level out of -15 to 15 range";
		}	
		else { $class->db_Main->{Profile} = $num; }
	}	
	sub printcol{
		#d: prints a table's col
		my $class =  shift;

		print $class->tb."'s columns are "; my $a;
		for (@{$class->cols}){$a++;print "$a.$_ " };print "\n"
	}
	sub cdbi_select {
		#d:display select
		my $class =  shift;

		my @aliasedinput = $class->inputalias(@_);
		my @results = $class->get_select(@aliasedinput);
		$class->has_a(path_id=>$class) if ($class->_flag->{join});

		#print results
		#open (PAGER,"| ".$class->_fh);
		#my $FH = ($class->_fh eq "STDOUT") ? "STDOUT" : "PAGER";
		$class->${\$class->_alias_print->{$class->_print_mode}}(\@results,$class->printcols,$class->_fh);
		#close PAGER;

		#pass obj for menu
		$class->lines(\@results) if ($class->_flag->{menu});
	}
	sub cdbi_delete {
		my $class =  shift;

		my @aliasedinput = $class->inputalias(@_);
		my %chosenf = $class->parseselect($class->_splitter,@aliasedinput) or die "parser failed: $@";
		$class->${\$class->_default_search}(%chosenf)->delete_all or die "delete failed: $@\n"; 
	}
	sub cdbi_insert {
		#d: inserts bookmark entry
		my $class =  shift;

		my %chosenf = $class->parseinsert(@_) or die "parser failed: $@";
		my $left = $class->create({%chosenf}) or die "couldn't create correctly: $@";
		return $left;
	} 
	sub replace {
		my $class = shift;

		my $op = pop(@_);
		my @aliasedinput = $class->inputalias(@_);
		my @records2update = $class->get_select(@aliasedinput);

		for my $rec (@records2update) {
			for (my $j=0; $j < @{$class->printcols}; $j++) {
				my $col= $class->printcols->[$j];
				$_ = $rec->$col;
				eval $op; die $@ if $@;
				$rec->$col($_);
			}
		$rec->update;
		}
	}
	sub verify_no_delim {
		my $class = shift;

		my @aliasedinput = $class->inputalias(@_);
		my @records2update = $class->get_select(@aliasedinput);
		my $clean = $class->verify_no_delim_obj(@records2update);
		print "No records containing delimiter found" if ($clean);
	}
	sub cdbi_update {
		#d: update fields in editor
		my $class =  shift;
		eval {require File::Temp};
		if ($@) {
			warn "File::Temp needed for this function ";
		}	
		else {
			my (undef,$tempfile) = File::Temp::tempfile();
			my @aliasedinput = $class->inputalias(@_);
			my @records2update = $class->get_select(@aliasedinput);

			if ($class->_flag->{safe_update}) {
				my $clean = $class->verify_no_delim_obj(@records2update);
				return if (not $clean);
			}

			$class->printtofile($tempfile,@records2update);

			my $modify = $class->modify_file($tempfile);
			#shift off commented lines
			$class->update_from_file($tempfile,@records2update) if ($modify);
		}	
	} 
	##functions whose input are objects
	sub verify_no_delim_obj {
		my ($class,@records) = @_;

		my @unclean_records =
		$class->check_for_regex($class->_delim->{display},@records);
		#$class->check_for_regex('a',@records);

		if (defined @unclean_records) {
			print "The following are records containing the delimiter '",
			$class->_delim->{display},"'\n\n";
			$class->print2darr(\@unclean_records,$class->printcols,'STDOUT');
			return 0;
		}
		#passed successfully
		return 1;
	}	
	sub delete_obj {
		my $proto = shift;
		my $class =  ref $proto || $proto;

		for (@_) { $_->delete; }
	}
	sub display_obj {
		my $class =  shift;
		$class->${\$class->_alias_print->{$class->_print_mode}}(\@_,$class->printcols,$class->_fh);
		#$class->print2darr(\@_,$class->printcols,'STDOUT');
	}
	sub update_obj {
		#t:menu
		my $class =  shift;
		my @records2update = @_;

		eval {require File::Temp};
		if ($@) {
			warn "File::Temp needed for this function ";
		}	
		else {
			my (undef,$tempfile) = File::Temp::tempfile();
			#h: prevent printing numbering
			$class->_flag->{menu}=0;
			$class->printtofile($tempfile,@records2update);
			my $modify = $class->modify_file($tempfile);

			#shift off commented lines
			$class->update_from_file($tempfile,@records2update) if ($modify);
		}	
	}
	sub direct_sql {
		#d:experimental
		my $class = shift;
		$sql_count++;

		$class->set_sql($sql_count=>"@_");
		my $method = "search_$sql_count";
		my @results = $class->$method;
		$class->print2darr(\@results,$class->printcols,'STDOUT');
	}
1;

__END__	

=head1 NAME

Basic.pm - A basic library of Class::DBI functions for use with Fry::Shell.

=head1 VERSION

This document describes version 0.05.

=head1 DESCRIPTION 

This module contain functions which provide commandline interfaces to search
methods and Class::DBI's &delete,&update,and &create methods. Also contains
some basic functions to enable and view DBI::Profile logs.

=head1 Shell functions

=over 4

=item B<printcol()>: prints the columns of the current table

=item B<set_db_log_level($num)>: sets the log level of DBI handle;

=item B<print_dbi_log()>: prints the current DBI log

=item B<clear_dbi_log()>: clears the DBI log

=item B<cdbi_insert(@search_terms)>: parses the input via __PACKAGE__->_delim->{insert} into values for each column

The columns which map to the parsed values is defined via the accessor
&insertcol. Ie if @insertcol = ('car','year') and the insert delimiter is
',,' and your input is 'chevy,,57' then &cdbi_insert will create
a record with car='chevy' and year='57'

note: records with multi-line data can't be inserted this way 

=back

=head2 Search-based functions	

The following are functions which perform queries with either &Class::DBI::search*
or &Class::DBI::AbstractSearch::search_where.

If Class::DBI::AbstractSearch isn't installed or the splitter matches
&_default_splitter then the given query is performed with the
Class::DBI search_* method specified by &_default_search.
Otherwise &search_where	is used. See &get_select for the decision logic.

Both methods split on white-space breaking up user's input to chunks
containing a column name and value pair. This chunk is in the form:
	
	$column$splitter$operator$column_value

	$splitter:  

		Class::DBI::search* -  is &_default_splitter accessor
		search_where - is the &_splitter accessor

	$operator: 

		Class::DBI::search* - doesn't support any
		search_where - can be any of '>,>=,<,<=,=,!=', valid only for &search_where   

		if no operator is given then the default operator specified in
		&_abstract_opts is used

For example the arguments 'hero=superman weakness=kryptonite' translates
to: (hero=>'superman',weakness=>'kryptonite') being passed to the search
function.  Assuming the default for _splitter('=') and _abstract_opts
under the generic table (TABLE) and generic columns (COLUMN1 COLUMN2
COLUMN3 ...):

=over 8

=item B<cdbi_select(@search_terms)>: prints results of query

	`cdbi_select tags=cool name=hack`  : select * from TABLE where tags ~ 'perl'
	and name ~ 'hack'

	`-c=1-3 cdbi_select id=>20 year=<=1980` : select COLUMN1,COLUMN2,COLUMN3 from TABLE
	where id > 20 and year <= 1980

note: if you don't understand -c look at section 'Option C'
below

=item B<cdbi_delete(@search_terms)>: deletes results found via query

	`cdbi_delete name=[aA]cme` : delete from TABLE where name ~
	'[aA]cme' 

=item B<cdbi_update(@search_terms)>: prints results found via the query to
file, user makes changes and fields updated automatically

Note: By default, the safe_update flag option is set. This 
prevents updating if a record containing the display delimiter is found.
It is important that the delimiter used to separate fields
in the file doesn't exist in the table's data. 
Otherwise incorrect parsing and updating of records will result.

Since this is slow for many records you may want to verify all the records
only once with &verify_no_delim.  To turn the flag off, you have to change it
inside &_default_data. Normally, you do this via your own config but there
currently isn't a way to define values in a hash in a config file.

=item B<replace(@search_terms,$operation)>: takes result of query and
	evaluates perl operation on each value of the results treating each
	value as $_
		
	`-c=1-4 replace description=cool s/cool/lame/g`

	This example gets the results of the SQL statement 
	" select COLUMN1,COLUMN2,COLUMN3,COLUMN4 from TABLE where
	description ~ 'cool' " and then performs 's/cool/lame/g' on the
	specified columns of each result row, treating each
	value as $_.	

note: Since $operation is distinguished from @search_terms by a
white space, $operation can't contain any white space.

=item B<verify_no_delim(@search_terms)>: verifies that no display delimiter
are in any of the queried records, provides an alternative to having to run
&cdbi_update safely

=back			

=head2 Menu Functions

The next three functions take Class::DBI row objects as input. The most common way
to pass these on is by first executing cdbi_select with the parse_mode= menu ('-m
cdbi_select tags=goofy') and then executing one of the following functions with numbers specifying
which objects you choose from the numbered menu. See handyshell.pl in the samples directory
for more about menu parsing mode.

=over 8

=item B<display_obj(@row_objects)>: prints chosen rows

=item B<delete_obj(@row_objects)>: deletes chosen rows 

=item B<update_obj(@row_objects)>: updates chosen rows via file as with &cdbi_update

=back
	
=head1 Global data

Here's a brief description of this module's global data:

	_editor: sets the editor used by &cdbi_update
	_splitter: separates column from its value in arguments of search-based functions and used
		for &Class::DBI::AbstractSearch::search_where searches	
	_default_splitter: same as above except used for Class::DBI::search* searches
	_default_search: Class::DBI search function called when _default_splitter appears in search functions
		possibilites are search,search_like and search_regex
	_abstract_opts: optional parameters passed to &Class::DBI:AbstractSearch::search_where
	_alias_print: hash mapping aliases to print functions
	_print_mode: current print alias used by _alias_print to determine current print mode,
		used by &cdbi_select
	_delim: hash with the following keys:
		display: delimits column values in table row printed out by &print2darr, also
			delimits column values when editing records in file with &cdbi_update
		insert: delimits values when using &cdbi_insert

=head1 Print Modes

Currently there are two main print modes (functions): text table and normal
Normal is on by default and simply delimits each column with ',,'  and row with "\n" by default.
Text table mode prints results as an aligned text table. I don't recommend this mode for a large
query as it has loop through the results beforehand to determine proper table formatting. To change
modes from the commandline you could specify '-P=t' as an option. To add another printing mode add
the alias to the accessor &_alias_print.

=head1 Handy Shortcuts

=head2 Input Aliasing

If there are queries you do often then you can alias them to an even shorter command via
&inputalias. The default &inputalias aliases 'a' to returning all rows of a table and replaces
anything matching /c\d/ with the corresponding column.

=head2 Option C

This option quickly specifes which columns to view by column numbers.
Columns are numbered in their order in a table. To view a numbered list of the
current table's columns type 'printcol'. For a table with
columns (id,name,author,book,year): 

	-c=1-3  : specifies columns id,name,author
	-c=1,4  : specifies columns id,book  
	-c=1-2,5 : specifies columns id,name,year

=head1 Writing Class::DBI Libraries

Make sure you've read Fry::Shell's 'Writing Libraries' section. 

When writing a Class::DBI library:

	1. Define 'CDBI::BDBI' as dependent module in your &_default_data.
	2. Refer to Fry::Lib::CDBI::BDBI for a list of core Class::DBI global data
	to use in your functions.

I encourage not only wrapper libraries around Class::DBI::* modules but any DBI
modules. Even table-specific libraries are welcome as I'll soon be releasing
libraries that generate outlines from a specific table format.

=head1 Suggested Modules

Three functions are dependent on external modules. Since their requirements are wrapped in
an eval, the functions fail safely.

	&cdbi_update: File::Temp
	&cdbi_select: Class::DBI::AbstractSearch
	&print_text_table: Text::Reform

=head1 See Also	

L<Fry::Shell>, L<Class::DBI>

=head1 TODO

 -defining relations between tables, should use Class::DBI::Loader to load tables 
 -provide direct SQL queries
 -support shell-like parsing of quotes to allow spaces in queries
 -specify sorting and limit of queries
 -embed sql or database functions in queries
 -create an easily-parsable syntax for piecing chunks into 'or' and 'and' parts
	to be passed to Class::DBI::AbstractSearch

=head1 Thanks	

I give a shot out to Kwan for encouraging me to check out Postgresql and Perl
when my ideas of a database shell were simply bash and a text file.

A shot out also to Jeff Bisbee for pointing me to Class::DBI when I was pretty
naive in the perl world.

=head1 AUTHOR

Me. Gabriel that is.  I welcome feedback and bug reports to cldwalker AT chwhat DOT com .  If you
like using perl,linux,vim and databases to make your life easier (not lazier ;) check out my website
at www.chwhat.com.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under the same terms as Perl
itself.
