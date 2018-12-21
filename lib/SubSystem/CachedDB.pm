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

=head1 BUGS

Please report any bugs or feature requests to C<bug-subsystem-cacheddb at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=SubSystem-CachedDB>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc SubSystem::CachedDB


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=SubSystem-CachedDB>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/SubSystem-CachedDB>

=item * CPAN Ratings

L<https://cpanratings.perl.org/d/SubSystem-CachedDB>

=item * Search CPAN

L<https://metacpan.org/release/SubSystem-CachedDB>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2018 mmacnair.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of SubSystem::CachedDB
