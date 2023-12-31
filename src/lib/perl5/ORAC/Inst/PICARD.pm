package ORAC::Inst::PICARD;

=head1 NAME

ORAC::Inst::ACSIS - ORAC description of PICARD virtual instrument

=head1 SYNOPSIS

  use ORAC::Inst::PICARD;

  %Mon = $inst->start_algorithm_engines;

=head1 DESCRIPTION

This module configures the system for the generic PICARD
instrument. This primarily involves configuring the messaging and
algorithm engine environment and is independent of the C<ORAC::Frame>
definition.

Algorithm engine definitions can be found in C<ORAC::Inst::Defn>.

=cut

use Carp;
use strict;
use vars qw/ $VERSION /;
$VERSION = '1.0';

use base qw/ ORAC::Inst /;

# Status handling
use ORAC::Constants qw/ :status /;
use ORAC::Inst::Defn qw/ orac_determine_initial_algorithm_engines /;

=head1 METHODS

=over 4

=item B<start_algorithm_engines>

Starts the algorithm engines and returns a hash containing the
objects associated with each monolith. The routine returns when
the last monolith can be contacted (so it requires that messaging
has been initialised before this routine is called).

=cut

sub start_algorithm_engines {
  my $self = shift;

# Retrieve algorithm requirements.
  my @engines = orac_determine_initial_algorithm_engines( 'PICARD' );

# And launch them.
  return $self->_launch_algorithm_engines( @engines );
}

=item B<return_possible_calibrations>

Returns an array containing a list of the possible calibrations
for PICARD.

=cut

sub return_possible_calibrations {
  my $self = shift;

  return ( );
}

=back

=head1 SEE ALSO

L<ORAC::Inst::Defn>

=head1 AUTHORS

Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>
Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2007 Science and Technology Facilities Council.
Copyright (C) 2004 Particle Physics and Astronomy Research
Council.  All Rights Reserved.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful,but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place,Suite 330, Boston, MA  02111-1307, USA

=cut

1;
