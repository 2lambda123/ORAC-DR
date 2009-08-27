package ORAC::Calib::UFTI;

=head1 NAME

ORAC::Calib::UFTI;

=head1 SYNOPSIS

  use ORAC::Calib::UFTI;

  $Cal = new ORAC::Calib::UFTI;

  @centre = $Cal->fpcentre;
  $Cal->fpcentre( @centre );

=head1 DESCRIPTION

This module contains methods for specifying UFTI-specific calibration
objects.  It provides a class derived from ORAC::Calib::IRCAM.  All the
methods available to ORAC::Calib::IRCAM objects are available to
ORAC::Calib::UFTI objects.

=cut

# Use standard error module and turn on strict declarations.
use Carp;
use warnings;
use strict;

use ORAC::Print;
use File::Spec;                         # Filename creation

use base qw/ORAC::Calib::IRCAM/;

use vars qw/$VERSION/;
$VERSION = '1.0';

__PACKAGE__->CreateBasicAccessors(
                                  fpcentre => { isarray => 1 },
);

=head1 METHODS

The following methods are available:

=head2 General Methods

=over 4

=item B<fpcentre>

Determine the pixel indices of the centre of the transmitted region of
the Fabry-Perot.  This allows for the cirular transmitted region to
have moved from its nominal location.

This method returns a semicolon-separated doublet "x;y" string rather
than a particular file even though it uses an index file.  Semicolon
is used to avoid problems with command-line parsing.

Croaks if it was not possible to determine a valid central co-ordinates.

  $fpcentre = $Cal->fpcentre;

If the noupdate flag is set there is no verification that the centre
co-rinates meets the specified rules (this is because the command-line
override uses a value rather than a file).

The index file must include a column named FPCENTRE.

=cut

sub fpcentre {
   my $self = shift;

# Handle arguments.
   return $self->fpcentrecache(shift) if @_;

# If noupdate is in effect we should return the cached value
# unless it is not defined.  This effectively allows the command-line
# value to be used to override without verifying its suitability.
   if ( $self->fpcentrenoupdate ) {
      my $cache = $self->fpcentrecache;
      return $cache if defined $cache;
   }

# Now we are looking for a value from the index file.
   my $fpcfile = $self->fpcentreindex->choosebydt( 'ORACTIME', $self->thing );
   croak "No suitable pixel location of the FP centre found in index file."
   unless defined $fpcfile;

# This gives us the filename, we now need to get the actual value
# of the pixel location of the centre of FP transmission.
   my $fpcref = $self->fpcentreindex->indexentry( $fpcfile );
   if ( exists $fpcref->{FPCENTRE} ) {
      return $fpcref->{FPCENTRE};
   } else {
      croak "Unable to obtain FPCENTRE from index file entry $fpcfile.\n";
   }
}

=back

=head2 Support Methods

Each of the methods above has a support implementation to obtain
the index file, current name and whether the value can be updated
or not. For method "cal" there will be corresponding methods
"calindex", "calname" and "calnoupdate". "calcache" is an
allowed synonym for "calname".

  $current = $Cal->calcache();
  $index = $Cal->calindex();
  $noup = $Cal->calnoupdate();

=head1 AUTHORS

Malcolm J. Currie (mjc@star.rl.ac.uk)

=head1 COPYRIGHT

Copyright (C) 2003 Particle Physics and Astronomy Research Council. 
All Rights Reserved.

=cut


1;
