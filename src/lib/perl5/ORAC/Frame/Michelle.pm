package ORAC::Frame::Michelle;

=head1 NAME

ORAC::Frame::Michelle - Michelle class for dealing with observation files in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Frame::Michelle;

  $Frm = new ORAC::Frame::Michelle("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to Michelle. It provides a class derived from
B<ORAC::Frame::UKIRT>.  All the methods available to B<ORAC::Frame::UKIRT>
objects are available to B<ORAC::Frame::Michelle> objects.

=cut

# A package to describe a Michelle group object for the
# ORAC pipeline

use 5.006;
use warnings;
use ORAC::Frame::CGS4;
use ORAC::Print;
use ORAC::General;

# Let the object know that it is derived from ORAC::Frame;
use base  qw/ORAC::Frame::CGS4/;

# standard error module and turn on strict
use Carp;
use strict;

use vars qw/$VERSION/;
'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Translation tables for Michelle should go here.
# First the imaging...
my %hdr = (
            RECIPE               => "RECIPE",
            DEC_SCALE            => "CDELT2",
            DEC_TELESCOPE_OFFSET => "TDECOFF",
            RA_SCALE             => "CDELT1",
            RA_TELESCOPE_OFFSET  => "TRAOFF",

# then the spectroscopy...
            CONFIGURATION_INDEX  => "CNFINDEX",
            GRATING_DISPERSION   => "GRATDISP",
            GRATING_NAME         => "GRATNAME",
            GRATING_ORDER        => "GRATORD",
            GRATING_WAVELENGTH   => "GRATPOS",
            SLIT_ANGLE           => "SLITANG",
            SLIT_NAME            => "SLITNAME",
            X_DIM                => "DCOLUMNS",
            Y_DIM                => "DROWS",

# then the general.
            CHOP_ANGLE           => "CHPANGLE",
            CHOP_THROW           => "CHPTHROW",
            DETECTOR_READ_TYPE   => "DETMODE",
            EXPOSURE_TIME        => "EXP_TIME",
            GAIN                 => "GAIN",
            NUMBER_OF_READS      => "NREADS",
            OBSERVATION_MODE     => "CAMERA"
	  );

# Take this lookup table and generate methods that can be sub-classed by
# other instruments.  Have to use the inherited version so that the new
# subs appear in this class.
# This will define the methods at runtime. The methods below this
# are defined at compile time and will be redefined by this call
# if there are clashes.
ORAC::Frame::Michelle->_generate_orac_lookup_methods( \%hdr );

# Certain headers appear in each .In sub-frame.  Special translation
# rules are required to represent the combined image, and thus should
# not appear in the above hash.  For example, the start time is that of
# the first sub-image, and the end time that of the sub-image.  These
# translation methods make use 

sub _to_DETECTOR_INDEX {
  my $self = shift;
  if( exists( $self->hdr->{ $self->nfiles } ) && exists( $self->hdr->{ $self->nfiles }->{DINDEX} ) ) {
    $self->hdr->{ $self->nfiles }->{DINDEX};
  }
}

sub _from_DETECTOR_INDEX {
  "DINDEX", $_[0]->uhdr("ORAC_DETECTOR_INDEX");
}

# Cater for early data with missing headers.
sub _to_NUMBER_OF_OFFSETS {
   my $self = shift;

# It's normally a ABBA pattern.  Add one for the final offset to 0,0.
   my $noffsets = 5;

# Look for a defined header containing integers.
   if ( exists $self->hdr->{NOFFSETS} ) {
      my $noff = $self->hdr->{NOFFSETS};
      if ( defined $noff && $noff =~ /\d+/ ) {
         $noffsets = $noff;
      }
   }
   return $noffsets;
}

# Cater for early data with missing values.
sub _to_NSCAN_POSITIONS {
   my $self = shift;

# Number of scan positions.
   my $nscan = undef;
   if ( exists $self->hdr->{DETNINCR} ) {
      $nscan = $self->hdr->{DETNINCR};
      if ( $nscan =~ /scan positions/ ) {
         $nscan = undef;
      }
   }
   return $nscan;
}

# Cater for early data with missing values.
sub _to_OBJECT {
   my $self = shift;

# Number of scan positions.
   my $object = undef;
   if ( exists $self->hdr->{OBJECT} ) {
      $object = $self->hdr->{OBJECT};
      if ( $object =~ /^Object Name/ ) {
         $object = undef;
      }
   }
   return $object;
}

# Cater for early data with missing values.
sub _to_SCAN_INCREMENT {
   my $self = shift;

# Number of scan positions.
   my $sincr = undef;
   if ( exists $self->hdr->{DETINCR} ) {
      $sincr = $self->hdr->{DETINCR};
      if ( $sincr =~ /[a-z]+/ ) {
         $sincr = undef;
      }
   }
   return $sincr;
}


# Cater for early data with missing values.
sub _to_STANDARD {
   my $self = shift;

# Whether or not observation is of a standard.
   my $standard = undef;
   if ( exists $self->hdr->{STANDARD} ) {
      $standard = $self->hdr->{STANDARD};
      if ( $standard !~ /[TF10]/ ) {
         $standard = undef;
      }
   }
   return $standard;
}

# Cater for early data with missing values.
sub _to_UTDATE {
   my $self = shift;

# This is UT start and time.
   my $utdate = undef;
   if ( exists $self->hdr->{UTDATE} ) {
      $utdate = $self->hdr->{UTDATE};
      if ( $utdate =~ /yyyymmdd/ ) {
         $utdate = undef;
      }
   }
   return $utdate;
}

sub _to_UTEND {
  my $self = shift;
  if( exists( $self->hdr->{ $self->nfiles } ) &&  exists( $self->hdr->{ $self->nfiles }->{UTEND} ) ) {
    $self->hdr->{ $self->nfiles }->{UTEND};
  }
}

sub _from_UTEND {
  "UTEND", $_[0]->uhdr("ORAC_UTEND");
}

sub _to_UTSTART {
  my $self = shift;
  if( exists( $self->hdr->{ 1 } ) &&  exists( $self->hdr->{ 1 }->{UTSTART} ) ) {
    $self->hdr->{ 1 }->{UTSTART};
  }
}

sub _from_UTSTART {
  "UTSTART", $_[0]->uhdr("ORAC_UTSTART");
}

# Specify the reference pixel, which is normally near the frame centre.
# Note that offsets for polarimetry are undefined.
sub _to_X_REFERENCE_PIXEL{
  my $self = shift;
  my $xref;

# Use the average of the bounds to define the centre.
  if ( exists $self->hdr->{RDOUT_X1} && exists $self->hdr->{RDOUT_X2} ) {
    my $xl = $self->hdr->{RDOUT_X1};
    my $xu = $self->hdr->{RDOUT_X2};
    $xref = nint( ( $xl + $xu ) / 2 );

# Use a default of the centre of the full array.
  } else {
    $xref = 161;
  }
  return $xref;
}

sub _from_X_REFERENCE_PIXEL {
  "CRPIX1", $_[0]->uhdr("ORAC_X_REFERENCE_PIXEL");
}

# Specify the reference pixel, which is normally near the frame centre.
# Note that offsets for polarimetry are undefined.
sub _to_Y_REFERENCE_PIXEL{
  my $self = shift;
  my $yref;

# Use the average of the bounds to define the centre.
  if ( exists $self->hdr->{RDOUT_Y1} && exists $self->hdr->{RDOUT_Y2} ) {
    my $yl = $self->hdr->{RDOUT_Y1};
    my $yu = $self->hdr->{RDOUT_Y2};
    $yref = nint( ( $yl + $yu ) / 2 );

# Use a default of the centre of the full array.
  } else {
    $yref = 121;
  }
  return $yref;
}

sub _from_Y_REFERENCE_PIXEL {
  "CRPIX2", $_[0]->uhdr("ORAC_Y_REFERENCE_PIXEL");
}

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from ORAC::Frame.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a ORAC::Frame::Michelle object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::Michelle;
   $Frm = new ORAC::Frame::Michelle("file_name");
   $Frm = new ORAC::Frame::Michelle("UT","number");

The constructor hard-wires the '.sdf' rawsuffix and the
'm' prefix although these can be overriden with the
rawsuffix() and rawfixedpart() methods.

=cut

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Run the base class constructor with a hash reference
  # defining additions to the class
  # Do not supply user-arguments yet.
  # This is because if we do run configure via the constructor
  # the rawfixedpart and rawsuffix will be undefined.
  my $self = $class->SUPER::new();

  # Configure initial state - could pass these in with
  # the class initialisation hash - this assumes that I know
  # the hash member name
  $self->rawfixedpart('m');
  $self->rawsuffix('.sdf');
#  $self->rawformat('UKIRTio');
  $self->rawformat('HDS');
  $self->format('HDS');

  # If arguments are supplied then we can configure the object
  # Currently the argument will be the filename.
  # If there are two args this becomes a prefix and number
  $self->configure(@_) if @_;

  return $self;
}

=back

=head2 General Methods

This section describes sub-classed methods.

=over 4

=item B<calc_orac_headers>

This method calculates header values that are required by the
pipeline by using values stored in the header.

Required ORAC extensions are:

ORACTIME: should be set to a decimal time that can be used for
comparing the relative start times of frames.  For UKIRT this
number is decimal hours, for SCUBA this number is decimal
UT days.

ORACUT: This is the UT day of the frame in YYYYMMDD format.

This method should be run after a header is set. Currently the readhdr()
method calls this whenever it is updated.

This method updates the frame header.
Returns a hash containing the new keywords.

=cut

sub calc_orac_headers {
  my $self = shift;

  # Run the base class first since that does the ORAC
  # headers
  my %new = $self->SUPER::calc_orac_headers;


  # ORACTIME
  # For Michelle the time must be extracted from the DATE-OBS keyword
  # and converted to decimal hours, formatted to five decimals. 
  # Return zero if not available.
  my $time;
  my $epoch = $self->hdr('DATE-OBS');
  if ( defined $epoch && $epoch =~ /:/ ) {
    my @hms = split( /:/, substr( $epoch, index( $epoch, "T" ) + 1 ) );
    $hms[ 2 ] =~ s/Z//;
    $time = $hms[ 0 ] + $hms[ 1 ] / 60.0 + $hms[ 2 ] / 3600.0;
    $time = sprintf( "%.5f", $time );
  } else {
    $time = 0;
  }
  $self->hdr('ORACTIME', $time);

  $new{'ORACTIME'} = $time;

  # ORACUT
  # For Michelle this is simply the UTDATE header value.
  my $ut = $self->hdr('UTDATE');
  $ut = 0 unless defined $ut;
  $self->hdr('ORACUT', $ut);

  return %new;
}

=back

=head1 SEE ALSO

L<ORAC::Frame::CGS4>

=head1 REVISION

$Id$

=head1 AUTHORS

Frossie Economou (frossie@jach.hawaii.edu)
Tim Jenness (t.jenness@jach.hawaii.edu)
Malcolm Currie (mjc@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 1998-2003 Particle Physics and Astronomy Research
Council. All Rights Reserved.


=cut

 
1;
