#!perl -T

use 5.006;
use strict;
use warnings;
use Test::More;

#use Test::Warnings qw/ :all /;
use Test::Exception;

my $module = $1 || 'SubSystem::CachedDB::DBI';
use_ok( $module ) || BAIL_OUT "Failed to use $module : [$!]";
dies_ok( sub { $module->new() }, 'New without settings fails correctly' );
my $db_file     = time . "_test_file.sqlite";
my @cache_names = qw/ yes no maybe /;
my $obj         = new_ok(
	$module,
	[
		{
			dsn => [
				"dbi:SQLite:$db_file",
				undef, undef,
				{
					AutoCommit                 => 1,
					RaiseError                 => 1,
					sqlite_see_if_its_a_number => 1,
				}

			],
			cache_names => \@cache_names,
		}
	]
);

is( ref( $obj->dbh ), 'DBI::db' );
ok(
	$obj->dbh->do( "
	CREATE TABLE test (
		id INTEGER PRIMARY KEY ,
		value STRING
	);
	create index id_index on test.id;
	create index value_index on test.value;
" )
);
$obj->dbh->do( "insert into test (value) values('start');" );

$obj->_commit();
my $last_insert = 1;

is( $obj->_last_insert, $last_insert );
$last_insert++;

my $cache_name = 'test_value_to_id';
$obj->mk_accessors( $cache_name );
ok( $obj->init_cache_for_accessors( [$cache_name] ) );
ok( $obj->_preserve_sth( 'test.get_id()', 'select id from test where value = ?' ) );
ok( $obj->_preserve_sth( 'test.set_id()', 'insert into test (value) values (?) ' ) );

my $new_value = time;
my $cache_key = "test_value_to_id.$new_value";
is(
	$obj->_cache_or_db_or_new(
		{
			cache          => 'test_value_to_id',
			cache_key      => $cache_key,
			get_sth_label  => 'test.get_id()',
			get_sth_params => [$new_value],
			set_sth_label  => 'test.set_id()',
			set_sth_params => [$new_value],

		}
	),
	$last_insert
);

is( $obj->_last_insert,                   $last_insert );
is( $obj->$cache_name->get( $cache_key ), $last_insert );
$last_insert++;
$obj->_commit();

delete( $obj->{sths} );
delete( $obj->{inited} );

$obj->{debug_level} = 1;

is( $obj->_cache_or_db_or_new_id_from_value( 'test', 'Victory' ), $last_insert );
is( $obj->$cache_name->get( 'test_id_from_value.Victory' ), $last_insert );
$obj->_commit();

$obj->clean_finish();
done_testing();
