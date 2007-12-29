package ORAC::Frame::SPEX;

=head1 NAME

ORAC::Frame::SPEX - SPEX class for dealing with observation files in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Frame::SPEX;

  $Frm = new ORAC::Frame::SPEX("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to SPEX.  It provides a class derived from
B<ORAC::Frame::UKIRT>.  All the methods available to
B<ORAC::Frame::UKIRT> objects are available to B<ORAC::Frame::SPEX>
objects.  Some additional methods are supplied.

=cut

# A package to describe a SPEX group object for the ORAC pipeline.

# standard error module and turn on strict
use Carp;
use strict;
use 5.006;
use warnings;
use vars qw/$VERSION/;
use ORAC::Frame::UKIRT;
use ORAC::Constants;
use ORAC::General;

# Let the object know that it is derived from ORAC::Frame::UKIRT;
use base qw/ORAC::Frame::UKIRT/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Translation tables for SPEX should go here
my %hdr = (
            EXPOSURE_TIME        => "ITIME",
            FILTER               => "GFLT"
	  );

# Alias file_from_bits as pattern_from_bits.
*pattern_from_bits = \&file_from_bits;

# Take this lookup table and generate methods that can be sub-classed
# by other instruments.  Have to use the inherited version so that the
# new subs appear in this class.
ORAC::Frame::SPEX->_generate_orac_lookup_methods( \%hdr );

sub _to_AIRMASS_START {
   my $self = shift;
   my $airmass = 1.0;
   if ( defined( $self->hdr->{AIRMASS} ) ) {
      $airmass = $self->hdr->{AIRMASS};
   }
   return $airmass;
}

sub _to_AIRMASS_END {
   my $self = shift;
   my $airmass = 1.0;
   if ( defined( $self->hdr->{AIRMASS} ) ) {
      $airmass = $self->hdr->{AIRMASS};
   }
   return $airmass;
}

sub _from_AIRMASS_END {
   "AMEND",  $_[0]->uhdr( "ORAC_AIRMASS_END" );
}

# Convert from sexagesimal d:m:s to decimal degrees.
sub _to_DEC_BASE {
   my $self = shift;
   my $dec = 0.0;
   my $sexa = $self->hdr->{"DECBASE"};
   if ( defined( $sexa ) ) {
      $dec = $self->dms_to_degrees( $sexa );
   }
   return $dec;
}

# Value stored in the headers is too imprecise.
sub _to_DEC_SCALE {
   -0.1182;
}

sub _to_DETECTOR_READ_TYPE {
   "NDSTARE";
}

# Assume that the initial offset is 0.0, i.e. the base is the
# source position.  This also assumes that the reference pixel
# is unchanged in the group, as is created in the conversion
# script.  The other headers are measured in sexagesimal, but 
# the offsets are in arcseconds.
sub _to_DEC_TELESCOPE_OFFSET {
   my $self = shift;
   my $offset;
   my $base = $self->_to_DEC_BASE();

# Convert from sexagesimal d:m:s to decimal degrees.
   my $sexadec = $self->hdr->{DEC};
   if ( defined( $sexadec ) ) {
      my $dec = $self->dms_to_degrees( $sexadec );

# The offset is arcseconds with respect to the base position.
      $offset = 3600.0 * ( $dec - $base );
   } else {
      $offset = 0.0;
   }
   return $offset;
}

# The gain is fixed.
sub _to_GAIN {
   13.0;
}

sub _to_INSTRUMENT {
   "SPEX";
}

sub _to_NSCAN_POSITIONS {
   1;
}

sub _to_NUMBER_OF_EXPOSURES {
   my $self = shift;
   my $coadds = 1;
   if ( defined $self->hdr->{CO_ADDS} ) {
      $coadds = $self->hdr->{CO_ADDS};
   }
   
}

sub _to_NUMBER_OF_OFFSETS {
   my $self = shift;

# Allow for the UKIRT convention of the final offset to 0,0, and a
# default dither pattern of 5.
   my $noffsets = 6;

# The number of gripu members appears to be given by keyword LOOP.
   if ( defined $self->hdr->{NOFFSETS} ) {
      $noffsets = $self->hdr->{NOFFSETS};
   }

   return $noffsets;
}

sub _to_OBSERVATION_MODE {
   "imaging";  # Single imaging mode
}

sub _to_OBSERVATION_TYPE {
   my $self = shift;
   my $type = "OBJECT";
   if ( defined $self->hdr->{OBJECT} && defined $self->hdr->{GFLT}) {
      my $object = uc( $self->hdr->{OBJECT} );
      my $filter = uc( $self->hdr->{GFLT} );
      if ( $filter =~ /blank/i ) {
         $type = "DARK";
      } elsif ( $object =~ /flat/i ) {
         $type = "FLAT";
      }
   }
   return $type;
}

# Convert from sexagesimal h:m:s to decimal degrees then to decimal
# hours.
sub _to_RA_BASE {
   my $self = shift;
   my $ra = 0.0;
   my $sexa = $self->hdr->{"RABASE"};
   if ( defined( $sexa ) ) {
      $ra = $self->hms_to_degrees( $sexa ) / 15.0;
   }
   return $ra;
}

# Value stored in the headers is too imprecise.
sub _to_RA_SCALE {
   -0.116;
}

# Assume that the initial offset is 0.0, i.e. the base is the
# source position.  This also assumes that the reference pixel
# is unchanged in the group, as is created in the conversion
# script.  The other headers are measured in sexagesimal, but
# the offsets are in arcseconds.
sub _to_RA_TELESCOPE_OFFSET {
   my $self = shift;
   my $offset;

# Base RA is in decimal hours.
   my $base = 15.0 * $self->_to_RA_BASE();

# Convert from sexagesimal right ascension h:m:s and declination
# d:m:s to decimal degrees.
   my $sexara = $self->hdr->{RA};
   my $sexadec = $self->hdr->{DEC};
   if ( defined( $base ) && defined( $sexara ) && defined( $sexadec ) ) {
      my $dec = $self->dms_to_degrees( $sexadec );
      my $ra = $self->hms_to_degrees( $sexara );

# The offset is arcseconds with respect to the base position.
      $offset = 3600.0 * ( $ra - $base ) * cosdeg( $dec );
   } else {
      $offset = 0.0;
   }
   return $offset;
}

sub _to_RECIPE {
   my $self = shift;
   my $recipe = "JITTER_SELF_FLAT";
   if ( $self->_to_OBSERVATION_TYPE() eq "DARK" ) {
      $recipe = "REDUCE_DARK";
   } elsif (  $self->_to_STANDARD() ) {
      $recipe = "JITTER_SELF_FLAT_APHOT";
   }
   return $recipe;
}

sub _to_ROTATION {
   -1.03; # assume good alignment for now.
}

sub _to_SPEED_GAIN {
   "Normal"; # don't know any better now. 
}

# Take a pragmatic way of defining a standard.  Not perfect, but
# should suffice unitl we know all the names.
sub _to_STANDARD {
   my $self = shift;
   my $standard = 0;
   my $object = $self->hdr->{"OBJECT"};
   if ( defined( $object ) && $object =~ /^FS/ ) {
      $standard = 1;
   }
   return $standard;
}

sub _to_TELESCOPE {
   "IRTF";
}

# Allow for multiple occurences of the date, the first being valid and
# the second is blank.
sub _to_UTDATE {
  my $self = shift;
  my $utdate;
  if ( exists $self->hdr->{"DATE-OBS"} ) {
     $utdate = $self->hdr->{"DATE-OBS"};

# This is a kludge to work with old data which has multiple values of
# the DATE keyword with the last value being blank (these were early
# SPEX data).  Return the first value, since the last value can be
# blank. 
     if ( ref( $utdate ) eq 'ARRAY' ) {
        $utdate = $utdate->[0];
     }
  }
  return $utdate;
}

# Derive from the start time, plus the exposure time and some
# allowance for the read time taken from 
# http://irtfweb.ifa.hawaii.edu/Facility/spex/work/array_params/array_params.html
sub _to_UTEND {
   my $self = shift;
   my $utend = $self->_to_UTSTART();
   if ( defined $self->hdr->{ITIME} && defined $self->hdr->{NDR} ) {
      $utend += ( $self->hdr->{ITIME} + 0.24 * $self->hdr->{NDR} ) / 3600.;
   }
   return $utend;
}

sub _from_UTEND {
   "UTEND",  $_[0]->uhdr( "ORAC_UTEND" );
}

sub _to_UTSTART {
   my $self = shift;

# Obtain the start time in seconds.
   return $self->get_UT_hours();
}

sub _to_X_LOWER_BOUND {
   my $self = shift;
   my @bounds = $self->get_bounds();
   return $bounds[ 0 ];
}

# Specify the reference pixel, which is normally near the frame centre.
sub _to_X_REFERENCE_PIXEL{
   my $self = shift;
   my $xref;

# Use the average of the bounds to define the centre and dimension.
   my @bounds = $self->get_bounds();
   my $xdim = $bounds[ 2 ] - $bounds[ 0 ] + 1;
   my $xmid = nint( ( $bounds[ 2 ] + $bounds[ 0 ] ) / 2 );

# SPEX is at the centre for a sub-array along an axis but offset slightly
# for a sub-array to avoid the joins between the four sub-array sections
# of the frame.  Ideally these should come through the headers...
   if ( $xdim == 512 ) {
      $xref = $xmid - 36;
   } else {
      $xref = $xmid;
   }
   return $xref;
}

sub _from_X_REFERENCE_PIXEL {
   "CRPIX1", $_[0]->uhdr("ORAC_X_REFERENCE_PIXEL");
}

sub _to_X_UPPER_BOUND {
   my $self = shift;
   my @bounds = $self->get_bounds();
   return $bounds[ 2 ];
}

sub _to_Y_LOWER_BOUND {
   my $self = shift;
   my @bounds = $self->get_bounds();
   return $bounds[ 1 ];
}

# Specify the reference pixel, which is normally near the frame centre.
sub _to_Y_REFERENCE_PIXEL{
   my $self = shift;
   my $yref;

# Use the average of the bounds to define the centre and dimension.
   my @bounds = $self->get_bounds();
   my $ydim = $bounds[ 3 ] - $bounds[ 1 ] + 1;
   my $ymid = nint( ( $bounds[ 3 ] + $bounds[ 1 ] ) / 2 );

# SPEX is at the centre for a sub-array along an axis but offset slightly
# for a sub-array to avoid the joins between the four sub-array sections
# of the frame.  Ideally these should come through the headers...
   if ( $ydim == 512 ) {
      $yref = $ymid - 40;
   } else {
      $yref = $ymid;
   }

   return $yref;
}

sub _from_Y_REFERENCE_PIXEL {
   "CRPIX2", $_[0]->uhdr("ORAC_Y_REFERENCE_PIXEL");
}

sub _to_Y_UPPER_BOUND {
   my $self = shift;
   my @bounds = $self->get_bounds();
   return $bounds[ 3 ];
}

# Supplementary methods for the translations
# ------------------------------------------

# Converts a sky angle specified in d:m:s format into decimal degrees.
# Argument is the sexagesimal format angle.
sub dms_to_degrees {
   my $self = shift;
   my $sexa = shift;
   my $dms;
   if ( defined( $sexa ) ) {
      my @pos = split( /:/, $sexa );
      $dms = $pos[ 0 ] + $pos[ 1 ] / 60.0 + $pos [ 2 ] / 3600.;
   }
   return $dms;
}

sub get_bounds {
   my $self = shift;
   my @bounds = ( 1, 1, 512, 512 );
   if ( exists $self->hdr->{ARRAY0} ) {
      my $boundlist = $self->hdr->{ARRAY0};
      @bounds = split( ",", $boundlist );

# Bounds count from zero.
      $bounds[ 0 ]++;
      $bounds[ 1 ]++;
   }
   return @bounds;
}
   
# Returns the UT date in yyyyMMdd format.
sub get_UT_date {
   my $self = shift;
   my $date = $self->hdr->{"DATE-OBS"};
   $date =~ s/-//g;
   return $date;
}

# Returns the UT time of observation in decimal hours.
sub get_UT_hours {
   my $self = shift;
   if ( exists $self->hdr->{"TIME-OBS"} && $self->hdr->{"TIME-OBS"} =~ /:/ ) {
      my ($hour, $minute, $second) = split( /:/, $self->hdr->{"TIME-OBS"} );
      return $hour + ($minute / 60) + ($second / 3600);
   } else {
      return $self->hdr->{"TIME-OBS"};
   }
}

# Converts a sky angle specified in h:m:s format into decimal degrees.
# It takes no account of latitude.  Argument is the sexagesimal format angle.
sub hms_to_degrees {
   my $self = shift;
   my $sexa = shift;
   my $hms;
   if ( defined( $sexa ) ) {
      my @pos = split( /:/, $sexa );
      $hms = 15.0 * ( $pos[ 0 ] + $pos[ 1 ] / 60.0 + $pos [ 2 ] / 3600. );
   }
   return $hms;
}

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Frame::UKIRT>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Frame::SPEX> object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::SPEX;
   $Frm = new ORAC::Frame::SPEX("file_name");
   $Frm = new ORAC::Frame::SPEX("UT","number");

The constructor hard-wires the '.fits' rawsuffix and the
'f' prefix although these can be overriden with the 
rawsuffix() and rawfixedpart() methods.

=cut

sub new {

   my $proto = shift;
   my $class = ref($proto) || $proto;

# Run the base class constructor with a hash reference defining
# additions to the class

# Do not supply user-arguments yet.  This is because if we do run
# configure via the constructor # the rawfixedpart and rawsuffix will
# be undefined.
   my $self = $class->SUPER::new();

# Configure initial state - could pass these in with the class
# initialisation hash - this assumes that we know  the hash member name.
   $self->rawfixedpart( 'spex' );
   $self->rawsuffix( '.sdf' );
   $self->rawformat( 'NDF' );
   $self->format( 'NDF' );

# If arguments are supplied then we can configure the object.  Currently
# the argument will be the filename.  If there are two args this becomes
# a prefix and number.
   $self->configure(@_) if @_;

   return $self;

}

=back

=head2 General Methods

=over 4

=item B<calc_orac_headers>

This method calculates header values that are required by the
pipeline by using values stored in the header.

Required ORAC extensions are:

ORACTIME: should be set to a decimal time that can be used for
comparing the relative start times of frames.  

ORACUT: This is the UT day of the frame in YYYYMMDD format.

This method should be run after a header is set.  Currently the readhdr()
method calls this whenever it is updated.

This method updates the frame header.  It returns a hash containing the new
keywords.

=cut

sub calc_orac_headers {
   my $self = shift;

# Run the base class first since that does the ORAC_
# headers
   my %new = $self->SUPER::calc_orac_headers;

# ORACTIME
# --------
# For SPEX this is the TIME-OBS header value converted to decimal hours.
   my $time = $self->get_UT_hours();

# Just return it (zero if not available).
   $time = 0 unless ( defined $time );
   $self->hdr( 'ORACTIME', $time );

   $new{'ORACTIME'} = $time;

# ORACUT
# ------
# Get the UT date.
   my $ut = $self->get_UT_date();
   $ut = 0 unless defined $ut;
   $self->hdr( 'ORACUT', $ut );

   $new{'ORACUT'} = $ut;

   return %new;
}

=item B<file_from_bits>

Determine the raw data filename given the variable component
parts.  A prefix (usually UT) and observation number should
be supplied.

  $fname = $Frm->file_from_bits($prefix, $obsnum);

For SPEX the raw filename after pressing by spex2oracdr.csh is
of the form:

  spexYYYYMMDD_NNNNN.sdf

where the number NNNNN is 0 padded.

=cut

sub file_from_bits {
   my $self = shift;

   my $prefix = shift;
   my $obsnum = shift;

# Zero pad the number.
   $obsnum = sprintf( "%05d", $obsnum );

# Temporary SPEX UKIRT-like form form is fixed prefix _ num suffix
   return $self->rawfixedpart . $prefix . '_' . $obsnum . $self->rawsuffix;

}

=item B<flag_from_bits>

Determine the name of the flag file given the variable
component parts. A prefix (usually UT) and observation number
should be supplied

  $flag = $Frm->flag_from_bits($prefix, $obsnum);

This particular method returns back the flag file associated with
SPEX.

=cut

sub flag_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  # It is almost possible to derive the flag name from the 
  # file name but not quite. In the SPEX case the flag name
  # is  .UT_obsnum.fits.ok but the filename is fUT_obsnum.fits

  # Retrieve the data file name
  my $raw = $self->pattern_from_bits($prefix, $obsnum);

  # Replace the 'f' with a '.' and append '.ok'
  substr($raw,0,1) = '.';
  $raw .= '.ok';
}

=item B<template>

Method to change the current filename of the frame (file())
so that it matches the current template. e.g.:

  $Frm->template("something_number_flat")

Would change the current file to match "something_number_flat".
Essentially this simply means that the number in the template
is changed to the number of the current frame object.

The base method assumes that the filename matches the form:
prefix_number_suffix. This must be modified by the derived
classes since in general the filenaming convention is telescope
and instrument specific.

=cut

sub template {
   my $self = shift;
   my $template = shift;

   my $num = $self->number;

# Pad with leading zeroes for a 5-digit obsnum.
   $num = "0" x ( 5 - length( $num ) ) . $num;

# Change the first number.
   $template =~ s/_\d+_/_${num}_/;

# Update the filename.
   $self->file( $template );

}

=item B<mergehdr>

Dummy method.

  $frm->mergehdr();

=cut


=back

=head1 SEE ALSO

L<ORAC::Group>

=head1 REVISION

$Id$

=head1 AUTHORS

Malcolm J. Currie E<lt>mjc@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2005 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut

1;
