package ORAC::Frame::WFCAM;

=head1 NAME

ORAC::Frame::WFCAM - WFCAM class for dealing with observation files in 
ORAC-DR 

=head1 SYNOPSIS

  use ORAC::Frame::WFCAM;

  $Frm = new ORAC::Frame::WFCAM("filename");
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to WFCAM prior to ORAC delivery. It provides a class derived
from B<ORAC::Frame::MEF>. Some additional methods are supplied.

=cut

# A package to describe a WFCAM Frame object for the
# ORAC pipeline

use 5.006;
use warnings;
use vars qw/$VERSION/;
use ORAC::Constants;
use ORAC::Frame::MEF;
use ORAC::Print;

# Let the object know that it is derived from ORAC::Frame::MEF;
use base qw/ORAC::Frame::MEF/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Alias file_from_bits as pattern_from_bits.
*pattern_from_bits = \&file_from_bits;

# standard error module and turn on strict
use Carp;
use strict;

# Translation tables for WFCAM should go here. Had to merge in the keywords
# from the UKIRT.pm class as this latter was base classed to NDF and I didn't
# feel like creating another FITS based class.

my %hdr = (
            AIRMASS_START       => "AMSTART",
            AIRMASS_END         => "AMEND",
            DEC_BASE            => "TELDEC",
            DEC_SCALE            => "CD2_1",
            DEC_TELESCOPE_OFFSET => "TDECOFF",
            DETECTOR_READ_TYPE  => "READOUT",
            EQUINOX             => "EQUINOX",
            EXPOSURE_TIME        => "EXP_TIME",
            FILTER              => "FILTER",
            GAIN                 => "GAIN",
            INSTRUMENT          => "INSTRUME",
            NUMBER_OF_OFFSETS   => "NJITTER",
            NUMBER_OF_EXPOSURES => "NEXP",
            OBJECT              => "OBJECT",
            OBSERVATION_NUMBER  => "OBSNUM",
            OBSERVATION_TYPE    => "OBSTYPE",
            RA_BASE             => "TELRA",
            RA_SCALE             => "CD1_2",
            RA_TELESCOPE_OFFSET  => "TRAOFF",
            READNOISE           => "READNOIS",
            RECIPE              => "RECIPE",
            ROTATION            => "CROTA2",
            SPEED_GAIN          => "SPD_GAIN",
            STANDARD            => "STANDARD",
            UTDATE               => "UTDATE",
            UTEND                => "DATE-END",
            UTSTART              => "DATE-OBS",
            X_LOWER_BOUND       => "RDOUT_X1",
            X_UPPER_BOUND       => "RDOUT_X2",
            Y_LOWER_BOUND       => "RDOUT_Y1",
            Y_UPPER_BOUND       => "RDOUT_Y2"
	  );

# Take this lookup table and generate methods that can be sub-classed
# by other instruments.  Have to use the inherited version so that the
# new subs appear in this class.

ORAC::Frame::WFCAM->_generate_orac_lookup_methods( \%hdr );

my %rawfixedparts = ('1' => 'w',
                     '2' => 'x',
                     '3' => 'y',
                     '4' => 'z',
                     '5' => 'v',
                    );

# Cubic distortion term values by filter

my %pv2_3 = ('J'       => -50.0,
	     'H'       => -50.0,
	     'K'       => -50.0,
	     'Y'       => -50.0,
	     'Z'       => -50.0,
	     'Blank'   => -50.0,
	     'Brgamma' => -50.0,
	     'OS1'     => -50.0,
	     'nominal' => -50.0);

# Central wavelengths for the WFCAM filters

my %cenwave = ('Z'      => 0.88,
               'Y'      => 1.02,
               'J'      => 1.25,
               'H'      => 1.64,
	       'K'      => 2.20,
               '1-0S1'  => 2.12,
	       'BGamma' => 2.17);

# Image sections to be used in determining the scale factor to use in 
# dark subtraction.

my @offsect = ("[10:19,951:960]",
	       "[2030:2039,1089:1098]",
	       "[1089:1098,10:19]",
	       "[951:960,2030:2039]");
my @onsect = ("[10:19,1089:1098]",
	      "[2030:2039,951:960]",
	      "[951:960,10:19]",
              "[1089:1098,2030:2039]");

# Keywords for primary header unit

my @phukeys = ("DATE","ORIGIN","TELESCOP","INSTRUME","DHSVER","HDTFILE",
	       "OBSERVER","USERID","OBSREF","PROJECT","SURVEY","SURVEY_I",
	       "MSBID","RMTAGENT","AGENTID","OBJECT","RECIPE","OBSTYPE",
	       "OBSNUM","GRPNUM","GRPMEM","TILENUM","STANDARD","NJITTER",
	       "JITTER_I","JITTER_X","JITTER_Y","NUSTEP","USTEP_I","USTEP_X",
	       "USTEP_Y","FILTER","UTDATE","UTSTART","UTEND","DATE-OBS",
	       "DATE-END","MJD-OBS","WCSAXES","RADESYS","EQUINOX","TRACKSYS",
	       "RABASE","DECBASE","TRAOFF","TDECOFF","AMSTART","AMEND","TELRA",
	       "TELDEC","GSRA","GSDEC","READMODE","EXP_TIME","NEXP","NINT",
	       "READINT","NREADS","AIRTEMP","BARPRESS","DEWPOINT","DOMETEMP",
	       "HUMIDITY","MIRR_NE","MIRR_NW","MIRR_SE","MIRR_SW","MIRRBTNW",
	       "MIRRTPNW","SECONDAR","TOPAIRNW","TRUSSENE","TRUSSWSW",
	       "WIND_DIR","WIND_SPD","CSOTAU","TAUDATE","TAUSRC","M2_X","M2_Y",
	       "M2_Z","M2_U","M2_V","M2_W","TCS_FOC","FOC_POSN","FOC_ZERO",
	       "FOC_OFFS","FOC_FOFF","FOC_I","FOC_OFF","NFOC","NFOCSCAN");

# Keywords for extension header unit

my @ehukeys = ("INHERIT","DETECTOR","DETECTID","DROWS","DCOLUMNS",
	       "RDOUT_X1","RDOUT_X2","RDOUT_Y1","RDOUT_Y2","PIXLSIZE","GAIN",
	       "CAMNUM","HDTFILE2","DET_TEMP","CNFINDEX","PCSYSID","SDSUID",
	       "READOUT","CAPPLICN","CAMROLE","CAMPOWER","RUNID","CTYPE1",
	       "CTYPE2","CRPIX1","CRPIX2","CRVAL1","CRVAL2","CRUNIT1",
	       "CRUNIT2","CD1_1","CD1_2","CD2_1","CD2_2","PV2_1","PV2_2",
	       "PV2_3");

=head1 PUBLIC METHODS

The following methods are available in this class in addition to
those available from B<ORAC::Frame::MEF>.

=head2 Constructor

=over 4

=item B<new>

Create a new instance of a B<ORAC::Frame::WFCAM> object.
This method also takes optional arguments:
if 1 argument is  supplied it is assumed to be the name
of the raw file associated with the observation. If 2 arguments
are supplied they are assumed to be the raw file prefix and
observation number. In any case, all arguments are passed to
the configure() method which is run in addition to new()
when arguments are supplied.
The object identifier is returned.

   $Frm = new ORAC::Frame::WFCAM;
   $Frm = new ORAC::Frame::WFCAM("file_name");
   $Frm = new ORAC::Frame::WFCAM("UT","number");

The constructor hard-wires the '.fits' rawsuffix and the
'f' prefix although these can be overriden with the 
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

  # Which WFCAM 'instrument' is this?  

  if ($ENV{'ORAC_INSTRUMENT'} =~ /^WFCAM([1-5])$/) {
      my $rfp = $rawfixedparts{lc($1)};
      $self->rawfixedpart($rfp);
      $self->{chipname} = [lc($1)];
  } else {
      $self->rawfixedpart('w_');
      $self->{chipname} = ["a","b","c","d"];
  }

  # Add in places where you can define which jitter or microstep sequence
  # this frame belongs to...

  $self->{ugrpname} = undef;
  $self->{jgrpname} = undef;

  # Configure initial state - could pass these in with
  # the class initialisation hash - this assumes that I know
  # the hash member name

  $self->rawsuffix('.sdf');
  $self->rawformat('HDS');
  $self->format('WFCAM_MEF');
#  $self->format('FITS');
  $self->fitssuffix('.fit');

  # If arguments are supplied then we can configure the object
  # Currently the argument will be the filename.
  # If there are two args this becomes a prefix and number

  $self->configure(@_) if @_;

  return $self;

}

=back

=head2 General Methods

=over 4

=item B<calc_orac_headers>

This method calculates header values that are required by the
pipeline by using values stored in the header.

An example is ORACTIME that should be set to the time of the
observation in hours. Instrument specific frame objects
are responsible for setting this value from their header.

Should be run after a header is set. Currently the hdr()
method calls this whenever it is updated.

Calculates ORACUT and ORACTIME

This method updates the frame header.
Returns a hash containing the new keywords.

=cut

sub calc_orac_headers {
  my $self = shift;

  use Time::Local;

  # Run the base class first since that does the ORAC_
  # headers

  my %new = $self->SUPER::calc_orac_headers;

  # ORACTIME
  # For WFCAM the keyword is derived from DATE-OBS. If it's not there then
  # this is probably an image extension.  In that case, just set it to
  # zero, because we're eventually going to splice the PHU header onto the
  # the extension header anyway.

  my $time = $self->hdr('DATE-OBS');
  my $t1 = 0;
  if (defined($time)) {
      $time =~ /(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})/;
      my $frac = $4/24.0 + $5/(24.0*60.0) + $6/(24.0*60.0*60.0);
      $t1 = sprintf("%4d%02d%02d",$1,$2,$3);
      $t1 += $frac;
#      $t1 = timegm($6,$5,$4,$3,$2-1,$1);
#      my $t0 = timegm(0,0,0,1,0,2001);
#      $t1 -= $t0;
  }
  $self->hdr('ORACTIME', $t1);
  $new{'ORACTIME'} = $t1;

  # Calc ORACUT:
  my $ut = $self->hdr('UTDATE');
  $ut = 0 unless defined $ut;
  $ut =~ s/-//g;  #  Remove the intervening minus sign

  $self->hdr('ORACUT', $ut);
  $new{ORACUT} = $ut;

  return %new;
}


=item B<file_from_bits>

Determine the raw data filename given the variable component
parts. A prefix (usually UT) and observation number should
be supplied.

  $fname = $Frm->file_from_bits($prefix, $obsnum);

pattern_from_bits() is currently an alias for file_from_bits(),
and both can be used interchangably for the WFCAM subclass.

=cut

sub file_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  # pad with leading zeroes - 5(!) digit obsnum

  my $padnum = sprintf("%05d",$obsnum);

  # WFCAM naming

  return $self->rawfixedpart . $prefix . '_' . $padnum . $self->rawsuffix;
}

=item B<flag_from_bits>

Determine the name of the flag file given the variable
component parts. A prefix (usually UT) and observation number
should be supplied

  $flag = $Frm->flag_from_bits($prefix, $obsnum);

This particular method returns back the flag file associated with
UFTI.

=cut

sub flag_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  # It is almost possible to derive the flag name from the 
  # file name but not quite. In the UFTI case the flag name
  # is  .UT_obsnum.fits.ok but the filename is fUT_obsnum.fits

  # Retrieve the data file name
  my $raw = $self->pattern_from_bits($prefix, $obsnum);

  # Add '.' and replace extension with '.ok'

  $raw =~ /^(.*?)\.(.*?)$/;
  $raw = '.' . $1 . '.ok';
}

# Supply a method to return the number associated with the observation

#=item B<number>

# Method to return the number of the observation. This is the
# number stored in the OBSNUM header

#   $number = $Frm->number;


### Note: this has been removed as it caused the -from -skip
### option combination to fail - FE

# =cut


# sub number {

#   my $self = shift;

#   my $number = $self->hdr('OBSNUM');

#   return $number;

# }


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

  # pad with leading zeroes - 5(!) digit obsnum

  $num = sprintf("%05d",$num);

  # Change the first number

  $template =~ s/_\d+_/_${num}_/;

  # Update the filename

  $self->file($template);

}

=back

=head2 Accessor Methods

The following extra accessor methods help individual chip identification and
WCS fitting. NB: these only return values and cannot be used for setting!

=over 4

=item B<chip>

Return the chip name associated with the frame.

    $Frm->chip;

=cut

sub chip {
    my $self = shift;

    return($self->{chipname});
}


=item B<pv2_3> 
Return the value of the cubic distortion coefficient 

    $Frm->pv2_3

=cut

sub pv2_3 {
    my $self = shift;

    # Get the filter...

    my $filt = $self->hdr("FILTER");

    # If it's defined then return it. If not, then send out a 
    # nominal value and warn...

    if (defined $pv2_3{$filt}) {
	return($pv2_3{$filt});
    } else {
	my $line = sprintf("Frame: %s -- can't define pv2_3 for filter %s\nUsing a nominal value\n",
			   $self->file,$filt);
	orac_warn($line);
	return($pv2_3{'nominal'});
    }
}
	


=item B<onoffsects>

Get a list of the off and on sections to be used in determining the scaleing
factor we need to subtract the dark frame. The returned values are references
to arrays containing the image sections to be used in the testing of the
reset anomaly regions.

    ($offsectref,$onsectref) = $Frm->onoffsects;

=cut

sub onoffsects {
    my $self = shift;

    return(\@offsect,\@onsect);
}

=item B<hdrkeys>

Find out what the WFCAM fits keyword for a particular ORAC header keyword

    $header_keywords = $Frm->hdrkeys($orac_keyword);

=cut

sub hdrkeys {
    my $self = shift;
    my $key = shift;

    return($hdr{$key});
}

=item B<ugrp>

Sets/returns the microstep sequence ID that this frame is part of

    $Frm->ugrp($ugrp);
    $ugrp = $Frm->ugrp;

=cut

sub ugrp {
    my $self = shift;
    if (@_) {
	$self->{ugrpname} = shift;
    }
    return($self->{ugrpname});
}

=item B<jgrp>

Sets/returns the jitter sequence ID that this frame is part of

    $Frm->jgrp($jgrp);
    $jgrp = $Frm->jgrp;

=cut

sub jgrp {
    my $self = shift;
    if (@_) {
	$self->{jgrpname} = shift;
    }
    return($self->{jgrpname});
}

=item B<isgood>

Decide whether you have a good image or not...Returns true if the frame is
good and false if not.

    $good = $Frm->isgood;

=cut

sub isgood {
    my $self = shift;

    # Are you trying to set it. If so, then set and return the value.

    if (@_) {
        $self->{IsGood} = shift;
        return($self->{IsGood});
    }

    # Otherwise, look for sources of problems. First look for the camera power

    my $good = $self->{IsGood};
    if ($good && $self->getasubframe(1)->hdr("CAMPOWER") ne "On") {
        $good = 0;
        my $line = "Frame " . $self->file . " will be ignored. Camera power is off\n";
        orac_warn($line);
    }
    $self->{IsGood} = $good;
    return ($good);
}

=item B<phukeys>

Returns the list of primary header unit keywords 
    @phukeys = $Frm->phukeys;

=cut

sub phukeys {
    my $self = shift;

    return(@phukeys);
}

=item B<ehukeys>

Returns the list of extension header unit keywords 
    @ehukeys = $Frm->ehukeys;

=cut

sub ehukeys {
    my $self = shift;

    return(@ehukeys);
}

=item B<cenwave> 

Return a central wavelength (in microns) given the filter name 
    $cenwave_H = $Frm->cenwave('H');

=cut

sub cenwave {
    my $self = shift;

    my $filter = shift;
    return($cenwave{$filter});
}

=item B<findgroup>
 
Returns group name from header.  If we cannot find anything sensible,
we return 0.  The group name stored in the object is automatically
updated using this value.
 
=cut

sub findgroup {
  
  my $self = shift;
  
  my $hdrgrp = $self->hdr('TILENUM');
  if (! $hdrgrp) {
      $hdrgrp = $self->hdr('GRPNUM');
  }
#  my $amiagroup;
  
  # NB: Test for GRPMEM is not 'T' as it used to be.  FITS header reader
  # now silently converts boolean values to 1 or 0.
  
#  if (!defined $self->hdr('GRPMEM')){
#    $amiagroup = 1;
#  } elsif ($self->hdr('GRPMEM') eq "1") {
#    $amiagroup = 1;
#  } else {
#    $amiagroup = 0;
#  }
                  
  # Is this group name set to anything useful
 
#  if (!$hdrgrp || !$amiagroup ) {
#    # if the group is invalid there is not a lot we can do
#    # so we just assume 0
#    $hdrgrp = 0;
#  }
 
  $self->group($hdrgrp);
 
  return $hdrgrp;
}
 
=head1 SEE ALSO

L<ORAC::Frame> L<ORAC::MEF>

=head1 REVISION

$Id$

=head1 AUTHORS

Jim Lewis (jrl@ast.cam.ac.uk)
Frossie Economou (frossie@jach.hawaii.edu)
Tim Jenness (timj@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 1998-2000 Particle Physics and Astronomy Research
Council. All Rights Reserved.


=cut

 
1;
