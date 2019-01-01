use strict;
use 5.006;
use warnings;

package SubSystem::CachedDB::DBI;
use base qw/ SubSystem::CachedDB/;
use SQL::Abstract;
use Data::Dumper;

=head1 NAME

	SubSystem::CachedDB::DBI - DBI with SQL Abstract and a cache 

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS


=head1 EXPORT


=head1 SUBROUTINES/METHODS

=head2 Facilitators
	specific to this module, i.e. 'how i'ma do this'
=cut

sub _init {
	my ( $self, $conf ) = @_;

	my @accessors = ( qw/dbh  sth_write_counter sth_write_limit /, @{$conf->{cache_names} || []} );
	__PACKAGE__->mk_accessors( @accessors );

	$self->SUPER::configure( $conf, [@accessors] );
	unless ( $self->dbh ) {
		unless ( ref( $conf->{dsn} ) eq 'ARRAY' ) {
			return {fail => "No DBH and no DSN provided - can't connect to database"};
		}
		use DBI;
		my $dbh = DBI->connect( @{$conf->{dsn}} ) or die $DBI::errstr;
		$self->dbh( $dbh );
	}
	$self->init_cache_for_accessors( $conf->{cache_names} || [] );
	$self->sth_write_limit ? 1 : $self->sth_write_limit( 100 );
	unless ( $self->sth_write_counter ) {
		my $v = 0;
		$self->sth_write_counter( \$v );
	}
	return {pass => 1};
}

sub _cache_or_carp {
	my ( $self, $p ) = @_;
	my $cache_accessor = "$p->{cache}";
	$self->can( $cache_accessor ) or Carp::croak( "No Cache accessor for $cache_accessor" );
	my $cache = $self->$cache_accessor or Carp::croak( "Cache not found through $cache_accessor" );
	return $cache;
}

sub _cache_or_db {
	my ( $self, $p ) = @_;
	for ( qw/cache cache_key get_sth_label get_sth_params  / ) {
		Carp::croak( "Missing [$_]" ) unless $p->{$_};
	}

	my $cache = $self->_cache_or_carp( $p );
	if ( my $v = $cache->get( $p->{cache_key} ) ) {
		$self->debug( "Cache hit for $p->{cache_key}", 2 );
		return $v;
	}

	$self->debug( "Cache miss for $p->{cache_key}", 2 );

	my $sth = $self->_preserve_sth( $p->{get_sth_label} );
	Carp::croak( "Missing sth for [$p->{get_sth_label}]" ) unless $sth;
	$sth->execute( @{$p->{get_sth_params}} );
	if ( my $row = $sth->fetchrow_hashref() ) {
		$self->debug( "DB hit for $p->{cache_key}", 2 );
		my $v = $row->{$p->{cache_value} || 'id'};

		# TODO use an optional sub to interpret DB values
		$cache->set( $p->{cache_key}, $v );
		return $v;
	}
	$self->debug( "DB miss for $p->{cache_key}", 2 );
	return;
}

sub _cache_or_db_or_new {
	my ( $self, $p ) = @_;

	return $self->_cache_or_db( $p ) || $self->_cache_new( $p );
}

sub _cache_new {
	my ( $self, $p ) = @_;

	for ( qw/cache set_sth_label set_sth_params cache_key / ) {
		Carp::croak( "Missing [$_]" ) unless $p->{$_};
	}
	my $cache = $self->_cache_or_carp( $p );

	my $sth = $self->_preserve_sth( $p->{set_sth_label} ) or die "Failed to retrieve sth for $p->{set_sth_label}";
	Carp::croak( "Missing sth for [$p->{set_sth_label}]" ) unless $sth;

	$sth->execute( @{$p->{set_sth_params}} ) or die $DBI::errstr;
	my $v = $self->_last_insert();

	$self->_commit_maybe();
	$cache->set( $p->{cache_key}, $v );
	$self->debug( "set($p->{cache_key},$v)", 2 );
	return $v;
}

sub _preserve_sth {
	my ( $self, $label, $qstring ) = @_;

	if ( $qstring ) {
		$self->debug( "setting $label qstring to $qstring", 2 );
		my $sth = $self->dbh->prepare( $qstring ) or die $DBI::errstr;
		$self->{sths}->{$label} = $sth;
	}
	return $self->{sths}->{$label};
}

sub _last_insert {
	my ( $self, $qstring ) = @_;
	my $sth = $self->_preserve_sth( 'last_insert' );

	unless ( $sth ) {
		$sth = $self->_preserve_sth( 'last_insert', $qstring || 'select last_insert_rowid();' );
	}
	unless ( $qstring ) {
		$sth->execute();
		return $sth->fetchrow_arrayref()->[0];
	}

}

sub _cache_or_db_or_new_id_from_value {
	my ( $self, $table, $value ) = @_;

	$self->_preserve_sth( "$table.get_id_from_value()", "select id from $table where value = ?" ) unless $self->_preserve_sth( "$table.get_id_from_value()" );
	$self->_preserve_sth( "$table.set_id_from_value()", "insert into $table (value) values (?)" ) unless $self->_preserve_sth( "$table.set_id_from_value()" );

	return $self->_cache_or_db_or_new(
		{
			cache          => "$table\_value_to_id",
			cache_key      => "$table\_id_from_value.$value",
			get_sth_label  => "$table.get_id_from_value()",
			get_sth_params => [$value],
			set_sth_label  => "$table.set_id_from_value()",
			set_sth_params => [$value],
		}
	);
}

sub _set_cache_or_db_or_new_id_from_value_sths {
	my ( $self, $table, $sth ) = @_;

}

sub _commit_maybe {
	my ( $self, $counter, $limit ) = @_;
	if ( $self->dbh->{AutoCommit} == 0 ) {
		$counter ||= $self->sth_write_counter;
		$limit   ||= $self->sth_write_limit;
		$$counter++;

		if ( $$counter >= $limit ) {

			return $self->_commit( $counter );
		}
		return 2;
	}
	return 3;
}

sub _commit {
	my ( $self, $counter ) = @_;

	if ( $self->dbh->{AutoCommit} == 0 ) {
		$self->debug( "\tCOMMIT", 1 );
		$self->dbh->commit();
		$$counter = 0;

		return 1;
	}
	return 3;
}

=head2 Critical Path
	These will be duplicated/translated in sibling modules 
=head3 clean_finish
	Close gracefully
=cut

sub clean_finish {
	my ( $self ) = @_;
	$self->_commit();
	delete( $self->{sths} );
	$self->dbh->disconnect();
}

=head3 id_for_value
	The whole point of the module, get a persistent integer id for a value 
=cut

sub id_for_value {
	my ( $self, $table, $value ) = @_;
	return $self->_cache_or_db_or_new_id_from_value( $table, $value );
}

# TODO value_for_id ?

=head1 AUTHOR

mmacnair, C<< <mmacnair at cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2018 mmacnair.

This program is distributed under the (Revised) BSD License:
L<http://www.opensource.org/licenses/BSD-3-Clause>

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

* Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.

* Neither the name of mmacnair's Organization
nor the names of its contributors may be used to endorse or promote
products derived from this software without specific prior written
permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1;
