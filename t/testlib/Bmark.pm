package Bmark;
#use strict;
use base 'PgBase';
our @columns = (qw/id name url tags notes/); 

__PACKAGE__->table('t_bmark');
__PACKAGE__->columns(All => @columns);
__PACKAGE__->sequence('t_bmark_id_seq');
#__PACKAGE__->setdb({pwd=>'',qw/tb bmark db postgres user bozo dbname template1/,db_opts=>{AutoCommit=>1}});

sub schema { "id serial not null primary key, name char varying (75) default '',url 
	char varying (100) default '',tags char varying (100) default '',notes char varying(75) default ''" } 

sub create_data {	 
	my $class = shift;
	my $sql = <<DATA ;
3,,Florida Clubs - SalsaPower ,,http://www.salsapower.com/cities/fl/broward_clubs.htm ,,sfl,salsa,clubs ,,,,
109,,Salsa Dance Patterns ,,http://www.geocities.com/salsero1234/salsa_patterns.htm ,,Music,dance,salsa ,,,,
110,,salsa-coursbravo ,,http://www.coursbravo.ch/Sud_ge.htm ,,Music,dance,salsa ,,,,
111,,level salsa ,,http://www.iro.umontreal.ca/~blais/public/salsa/rueda_montreal.html ,,salsa,Music,dance ,,,,
112,,rueda salsa ,,http://www.ttdomain.com/salsanewssingapore/reuda_command.htm ,,Music,dance,salsa ,,,,
421,,marks vim page ,,http://mark.stosberg.com/Tech/text_editor_review.html ,,vim ,,text editor comparison                                                     ,,
477,,http://iijo.org/,,http://iijo.org/,,vim,script,perl,python,,vim_debugger,,
514,,vim yahoo list ,,http://groups.yahoo.com/group/vim/messages ,,vim,list ,,vim list                                                                   ,,
581,,perl vim ,,http://www.leonid.maks.net/writings/vim-for-perl-dev/ ,,vim,soon ,,using perl in vim                                                          ,,
614,, ,,http://www.rayninfo.co.uk/vimtips.html ,,vim,config ,,well commented vimrc                                                       ,,
DATA
#INSERT INTO t_bmark VALUES (1, 'perl vim ', 'http://www.leonid.maks.net/writings/vim-for-perl-dev/ ', 'perl,vim,soon ', 'using perl in vim');
#INSERT INTO bmark VALUES (2, 'oops', 'http://ooopps.sourceforge.net/pub/', 'perl,script,OO,tutorial,script', NULL);
#COPY t_bmark (id, name, url, tags, notes) FROM stdin with delimiter as ',,';
#1,,testin,,now,,well,,
#357	testin                                                                     	now                                                                                                 	well
#DATA
	my @sql =  split(/\n/,$sql);
	for (@sql) {
		#$class->db_Main->do($sql);
		my @values = split(/,,/);
		my %inserthash;
		for my $i (0 .. @values -1) {
			$inserthash{$columns[$i]} = $values[$i]; 
		}	
		$class->create(\%inserthash);
	}	
}	
sub db_setup {
	my $class = shift;
	eval { $class->create_temp_table; };
	if ($@) {
		my $diag = <<SKIP;
	Pg connection failed ($@). Set env variables DBD_PG_DBNAME,  DBD_PG_USER,
	DBD_PG_PASSWD to enable testing with proper database,user and password.
SKIP
		&{"$class\::diag"}($diag);	
		&{"$class\::plan"}(skip_all => 'Pg connection failed.');
	};
	$class->create_data;
}	
1;
