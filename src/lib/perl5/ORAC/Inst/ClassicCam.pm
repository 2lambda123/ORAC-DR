package ORAC::Inst::ClassicCam;

=head1 NAME

ORAC::Inst::ClassicCam - ORAC description of ClassicCam

=head1 SYNOPSIS

  use ORAC::Inst::ClassicCam;

  %Mon = $inst->start_algorithm_engines;

=head1 DESCRIPTION

This module configures the system for the instrument.  This primarily
involves configuring the messaging and algorithm engine environment
and is independent of the C<ORAC::Frame> definition.

Algorithm engine definitions can be found in C<ORAC::Inst::Defn>.

=cut

use Carp;
use strict;
use vars qw/$VERSION/;
$VERSION = '1.0';

use base qw/ ORAC::Inst /;

# Status handling
use ORAC::Constants qw/:status/;

use ORAC::Inst::Defn qw/ orac_determine_initial_algorithm_engines /;


=head1 METHODS

=over 4

=item B<start_algorithm_engines>

Starts the algorithm engines and returns a hash containing
the objects associated with each monolith.
The routine returns when all the last monolith can be contacted
(so requires that messaging has been initialised before this
routine is called).

ClassicCam uses PHOTOM (photom_mon), CCDPACK (ccdpack_red, ccdpack_res,
ccdpack_reg), KAPPA (kappa_mon, ndfpack_mon), POLPACK (polpack_mon),
CURSA (catselect) and EXTRACTOR (extractor).

=cut

sub start_algorithm_engines {
  my $self = shift;

  # Retrieve algorithm requirements
  my @engines = orac_determine_initial_algorithm_engines( 'ClassicCam' );

  # Now launch them
  return $self->_launch_algorithm_engines( @engines );

}

=item B<return_possible_calibrations>

Returns an array containing a list of the possible calibrations
for this instrument.

=cut

sub return_possible_calibrations {
  my $self = shift;
  return ( "bias", "dark", "flat", "mask", "sky", "badobs", "readnoise", "referenceoffset" );

}

=back

=head1 SEE ALSO

L<ORAC::Inst::UFTI>

=head1 AUTHORS

Malcolm J. Currie E<lt>mjc@jach.hawaii.eduE<gt>.

=head1 COPYRIGHT

Copyright (C) 2003 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
