package ORAC::Group::ACSIS;

=head1 NAME

ORAC::Group::ACSIS - ACSIS class for dealing with observation groups in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Group;

  $Grp = new ORAC::Group::ACSIS("group1");
  $Grp->file("group_file")
  $Grp->readhdr;
  $value = $Grp->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling group objects that
are specific to ACSIS. It provides a class derived from B<ORAC::Group::NDF>.
All the methods available to B<ORAC::Group> objects are available
to B<ORAC::Group::ACSIS> objects.

=cut

# A package to describe a ACSIS group object for the
# ORAC pipeline

use 5.006;
use strict;
use warnings;
our $VERSION;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

use ORAC::Group::NDF;

use base qw/ ORAC::Group::NDF /;

# Header translation lookup table.
my %hdr = ( AIRMASS_START => 'AMSTART',
            AIRMASS_END => 'AMEND',
            CHOP_ANGLE => 'CHOP_PA',
            CHOP_THROW => 'CHOP_THR',
            DEC_BASE => 'CRVAL1',
            DEC_SCALE => 'CDELT1',
            EQUINOX => 'EQUINOX',
            EXPOSURE_TIME => 'INT_TIME',
            GRATING_DISPERSION => 'CDELT3',
            GRATING_WAVELENGTH => 'CRVAL3',
            INSTRUMENT => 'INSTRUME',
            NUMBER_OF_EXPOSURES => 'N_EXP',
            OBJECT => 'OBJECT',
            OBSERVATION_NUMBER => 'OBSNUM',
            RA_BASE => 'CRVAL2',
            RA_SCALE => 'CDELT2',
            RECIPE => 'DRRECIPE',
            STANDARD => 'STANDARD',
            UTDATE => 'UTDATE',
            WAVEPLATE_ANGLE => 'SKYANG',
          );

# Take this lookup table and generate methods that can
# be sub-classed by other instruments
ORAC::Group::ACSIS->_generate_orac_lookup_methods( \%hdr );

# Now for the translations that require calculations and whatnot.

sub _to_UTSTART {
  my $self = shift;
  my $utstart = $self->hdr->('DATE-OBS');
  return if ( ! defined( $utstart ) );
  $utstart =~ /T(\d\d):(\d\d):(\d\d)/;
  my $hour = $1;
  my $minute = $2;
  my $second = $3;
  $hour + ( $minute / 60 ) + ( $second / 3600 );
}

sub _from_UTSTART {
  my $starttime = $_[0]->uhdr("ORAC_UTSTART");
  my $startdate = $_[0]->uhdr("ORAC_UTDATE");
  $startdate =~ /(\d{4})(\d\d)(\d\d)/;
  my $year = $1;
  my $month = $2;
  my $day = $3;
  my $hour = int( $starttime );
  my $minute = int( ( $starttime - $hour ) * 60 );
  my $second = int( ( ( ( $starttime - $hour ) * 60 ) - $minute ) * 60 );
  my $return = ( join "-", $year, $month, $day ) . "T" . ( join ":", $hour, $minute, $second );
  return "DATE-OBS", $return;
}

sub _to_UTEND {
  my $self = shift;
  my $utend = $self->hdr->('DATE-END');
  return if ( ! defined( $utend ) );
  $utend =~ /T(\d\d):(\d\d):(\d\d)/;
  my $hour = $1;
  my $minute = $2;
  my $second = $3;
  $hour + ( $minute / 60 ) + ( $second / 3600 );
}

sub _from_UTEND {
  my $endtime = $_[0]->uhdr("ORAC_UTEND");
  my $enddate = $_[0]->uhdr("ORAC_UTDATE");
  $enddate =~ /(\d{4})(\d\d)(\d\d)/;
  my $year = $1;
  my $month = $2;
  my $day = $3;
  my $hour = int( $endtime );
  my $minute = int( ( $endtime - $hour ) * 60 );
  my $second = int( ( ( ( $endtime - $hour ) * 60 ) - $minute ) * 60 );
  my $return = ( join "-", $year, $month, $day ) . "T" . ( join ":", $hour, $minute, $second );
  return "DATE-END", $return;
}

sub _to_TELESCOPE {
  return "JCMT";
}

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Group>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of an B<ORAC::Group::ACSIS> object. This method
takes an optional argument containing the name of the new group.
The object identifier is returned.

  $Grp = new ORAC::Group::ACSIS;
  $Grp = new ORAC::Group::ACSIS("group_name");

This method calls the base class constructor but initialises the group
with a file suffix if ".sdf" and a fixed part of "ga".

=cut

sub new {
  my $proto = shift;
  my $class = ref( $proto ) || $proto;

# Do not pass objects if the constructor required
# knowledge of fixedpart() and filesuffix().
  my $group = $class->SUPER::new(@_);

# Configure it.
  $group->fixedpart('ga');
  $group->filesuffix('.sdf');

# And return the new object.
  return $group;
}

=back

=head2 General Methods

=over 4

=item B<calc_orac_headers>

This method calculates header values that are required by the
pipeline by using values stored in the header.

Should be run after a header is set. Currently the hdr() method
calls this whenever it is updated.

Calculates ORACUT and ORACTIME.

ORACUT is the UT date in YYYYMMDD format.
ORACTIME is the time of the observation in YYYYMMDD.fraction format.

This method updates the frame header.

This method returns a hash containing the new keywords.

=cut

sub calc_orac_headers {
  my $self = shift;

  # Run the base class first since that does the ORAC_
  # header translations.
  my %new = $self->SUPER::calc_orac_headers;

  # ORACTIME - in decimal UT days.
  my $uthour = $self->uhdr('ORAC_UTSTART');
  my $utday = $self->uhdr('ORAC_UTDATE');
  $self->hdr('ORACTIME', $utday + ( $uthour / 24 ) );
  $new{'ORACTIME'} = $utday + ( $uthour / 24 );

  # ORACUT - in YYYYMMDD format
  my $ut = $self->uhdr('ORAC_UTDATE');
  $ut = 0 unless defined $ut;
  $self->hdr('ORACUT', $ut);
  $new{'ORACUT'} = $ut;

  return %new;
}

=item B<file_from_bits>

Method to return the group filename derived from a fixed
variable part (eg UT) and a group designator (usually obs
number). The full filename is returned (including suffix).

  $file = $Grp->file_from_bits("UT","num","extra");

For ACSIS the return string is of the format

  fixedpart . prefix . '_' . number . '_' . extra . suffix

=cut

sub file_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $num = shift;
  my $extra = shift;

  # Follow UKIRT style
  return $self->fixedpart . $prefix . '_' . $num . '_' . $extra . $self->filesuffix;
}

=back

=head1 SEE ALSO

L<ORAC::Group::NDF>

=head1 REVISION

$Id$

=head1 AUTHORS

Brad Cavanagh E<lt>b.cavanagh@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2007-2008 Science and Technology Facilities Council.
Copyright (C) 2004-2007 Particle Physics and Astronomy Research
Council. All Rights Reserved.

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
