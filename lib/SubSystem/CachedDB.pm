use strict;
use 5.006;
use warnings;

package SubSystem::CachedDB;

use Carp qw/ carp croak cluck/;
use Module::Runtime qw/require_module/;
use base qw/Class::Accessor /;

=head1 NAME

SubSystem::CachedDB - The great new SubSystem::CachedDB!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use SubSystem::CachedDB;

    my $foo = SubSystem::CachedDB->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 function1

=cut

sub new {
	my ( $class, $conf ) = @_;
	my $self = {};
	bless $self, $class;
	my $initresult = $self->_init( $conf );
	die $initresult->{fail} unless $initresult->{pass};
	return $self;
}

sub _init {
	my ( $self, $conf ) = @_;

	return {fail => "Non useful init"};
}

=head2
	transfer $conf keys to $self, or the corresponding accessor
=cut

sub configure {
	my ( $self, $conf, $keys ) = @_;
	$keys = [] unless $keys;
	for ( @{$keys} ) {
		if ( exists( $conf->{$_} ) ) {
			if ( $self->can( $_ ) ) {
				$self->$_( $conf->{$_} );
			} else {
				$self->{$_} = $conf->{$_};
			}
		}
	}
}

sub init_cache_for_accessors {
	my ( $self, $cache_names, $p ) = @_;
	for ( @{$cache_names} ) {
		croak( "Accessor not set for cache $_" ) unless $self->can( $_ );
		unless ( $self->$_ ) {
			Module::Runtime::require_module( $p->{cache_type} || "Cache::Memory" );
			my $cache_params = $p->{cache_params} || [ namespace => $_, default_expires => '100 sec' ];
			my $cache = Cache::Memory->new( @{$cache_params} );
			$self->$_( $cache );
		}
	}
	return $self;
}

sub debug {
	my ( $self, $msg ) = @_;
	Carp::carp( $msg ) if $self->{debug_level};
}

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

1; # End of SubSystem::CachedDB
