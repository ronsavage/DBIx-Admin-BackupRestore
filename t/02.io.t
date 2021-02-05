#!perl

use strict;
use warnings;

use Data::Dumper::Concise; # For Dumper().

use DBIx::Admin::BackupRestore;

use File::Spec;
use File::Temp;

use Test::More;

# ---------------------------------------------

eval "use DBI";
plan skip_all => "DBI required for testing DB plugin" if $@;

# The EXLOCK option is for BSD-based systems.

my($out_dir)	= File::Temp -> newdir('temp.XXXX', CLEANUP => 1, EXLOCK => 0, TMPDIR => 1);
my($db_file)	= File::Spec -> catfile($out_dir, 'test.sqlite');
$db_file		= '/tmp/test.sqlite';
my($xml_file)	= File::Spec -> catfile($out_dir, 'test.xml');
$xml_file		= '/tmp/test.xml';

plan skip_all => "Temp dir is un-writable" if (! -w $out_dir);

unlink $db_file;
unlink $xml_file;

if (! $ENV{DBI_DSN})
{
	eval "use DBD::SQLite";
	plan skip_all => "DBD::SQLite required for testing DB plugin" if $@;

	$ENV{DBI_DSN}	= "dbi:SQLite:dbname=$db_file";
	$ENV{DBI_USER}	= '';
	$ENV{DBI_PASS}	= '';
}

plan tests => 2;

my(@opts)	= ($ENV{DBI_DSN}, $ENV{DBI_USER}, $ENV{DBI_PASS});
my($dbh)	= DBI->connect(@opts, {RaiseError => 1, PrintError => 0, AutoCommit => 1});

$dbh -> do( <<"__END_SQL__" );
create table t1 (
	id int not null primary key
	,value varchar(255)
)
__END_SQL__

$dbh -> do( <<"__END_SQL__" );
insert into t1
    ( id, value )
values
    ( 1, 'Record one' )
   ,( 2, 'Record two' )
__END_SQL__

$dbh -> do( <<"__END_SQL__" );
create table t2 (
	id int not null primary key
	,value varchar(255)
)
__END_SQL__

$dbh -> do( <<"__END_SQL__" );
insert into t2
    ( id, value )
values
    ( 1, 'Record three' )
   ,( 2, 'Record four' )
__END_SQL__

# Backup phase.

open(OUT, "> $xml_file") || die("Can't open(> $xml_file): $!");
print OUT DBIx::Admin::BackupRestore -> new(dbh => $dbh) -> backup($db_file);
close OUT;

note "Wrote SQLite file $db_file";
note "Wrote XML file $xml_file";

ok(-r $db_file, "$db_file is readable");
ok(-r $xml_file, "$xml_file is readable");

# Restore phase.

my($table_names) = DBIx::Admin::BackupRestore -> new(dbh => $dbh) -> restore($xml_file);

note 'Tables retrieved: ', Dumper($table_names);
