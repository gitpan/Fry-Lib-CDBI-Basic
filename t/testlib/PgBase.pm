package PgBase;
use strict;
use ExtUtils::MakeMaker;
use base 'Class::DBI';

#my $db   = $ENV{DBD_PG_DBNAME} || 'template1';
#my $user = $ENV{DBD_PG_USER}   || 'postgres';
#my $pass = $ENV{DBD_PG_PASSWD} || '';
our $db = prompt("Enter postgresql database ","template1");# || "template1";
our $user = prompt("Enter user ","postgres");# || "postgres";
our $pass = prompt("Enter password ['']: ");# || '';

__PACKAGE__->set_db( Main => "dbi:Pg:dbname=$db", $user, $pass, { AutoCommit => 1 });

sub create_temp_table {
	my $class = shift;
	my ($table, $sequence,$schema) = ($class->table, $class->sequence,$class->schema);
	#$class->db_Main->do( "CREATE TEMPORARY SEQUENCE $sequence");
	$class->db_Main->do( "CREATE TEMPORARY TABLE $table ( $schema )" );
}
#sub prompt {
	#print $_[0];
	#chomp(my $input = <STDIN>);
	#return $input;
#
#}	
sub CONSTRUCT {
  my $class = shift;
  $class->db_Main->do( "CREATE TABLE ".$class->table." ( ".$class->schema .")" );
  #my ($table, $sequence) = ($class->table, $class->sequence || "");
  #my $schema = $class->schema;
  #$class->db_Main->do( "CREATE TEMPORARY SEQUENCE $sequence") if $sequence;
}

1;
