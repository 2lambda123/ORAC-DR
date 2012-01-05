package ORAC::Frame::JCMT;

=head1 NAME

ORAC::Frame::JCMT - JCMT class for dealing with observation files in
ORAC-DR.

=head1 SYNOPSIS

  use ORAC::Frame::JCMT;

  $Frm = new ORAC::Frame::JCMT( "filename" );

=head1 DESCRIPTION

This module provides methods for handling Frame objects that are
specific to JCMT instruments. It provides a class derived from
B<ORAC::Frame::NDF>. All the methods available to B<ORAC::Frame>
objects are also available to B<ORAC::Frame::JCMT> objects.

=cut

use 5.006;
use strict;
use warnings;
use warnings::register;

use vars qw/ $VERSION /;
use Carp;
use base qw/ ORAC::Frame::NDF /;

use JSA::Headers qw/ read_jcmtstate /;
use ORAC::Print;
use ORAC::Error qw/ :try /;

$VERSION = '1.02';

# Map AST Sky SYSTEM to JCMT TRACKSYS
my %astToJCMT = (
                 AZEL => "AZEL",
                 GAPPT => "APP",
                 GALACTIC => "GAL",
                 ICRS => "ICRS",
                 FK4 => "B1950",
                 FK5 => "J2000",
                );

my %JCMTToAst = map { $astToJCMT{$_}, $_ } keys %astToJCMT;

=head1 PUBLIC METHODS

The following methods are available in this class in addition to those
available from B<ORAC::Frame>.

=head2 Accessors

=over 4

=item B<allow_header_sync>

Whether or not to allow automatic header synchronization when the
Frame is updated via either the C<file> or C<files> method.

  $Frm->allow_header_sync( 1 );

For modern JCMT instruments, defaults to true (1).

=cut

sub allow_header_sync {
  my $self = shift;

  if( ! defined( $self->{AllowHeaderSync} ) ) {
    $self->{AllowHeaderSync} = 1;
  }

  if( @_ ) { $self->{AllowHeaderSync} = shift; }

  return $self->{AllowHeaderSync};
}

=back

=head2 General Methods

=over 4

=item B<jcmtstate>

Return a value from either the first or last entry in the JCMT STATE
structure.

  my $value = $Frm->jcmtstate( $keyword, 'end' );

If the supplied keyword does not exist in the JCMT STATE structure,
this method returns undef. An optional second argument may be given,
and must be either 'start' or 'end'. If this second argument is not
given, then the first entry in the JCMT STATE structure will be used
to obtain the requested value.

Both arguments are case-insensitive.

=cut

sub jcmtstate {
  my $self = shift;

  my $keyword = uc( shift );
  my $which = shift;

  if( defined( $which ) && uc( $which ) eq 'END' ) {
    $which = 'END';
  } else {
    $which = 'START';
  }

  # First, check our cache.
  if( exists $self->{JCMTSTATE} ) {
    return $self->{JCMTSTATE}->{$which}->{$keyword};
  }

  # Get the first and last files in the Frame object.
  my $first = $self->file( 1 );
  my $last = $self->file( $self->nfiles );

  # Reference to hash bucket in cache to simplify
  # references in code later on
  my $startref = $self->{JCMTSTATE}->{START} = {};
  my $endref = $self->{JCMTSTATE}->{END} = {};

  # QL data from SCUBA-2 DREAM/STARE will not have JCMTSTATE
  my $E;
  try {
    # if we have a single file read the start and end
    # read the start and end into the cache regardless
    # of what was requested in order to minimize file opening.
    if ($first eq $last ) {
      my %values = read_jcmtstate( $first, [qw/ start end /] );
      for my $key ( keys %values ) {
        $startref->{$key} = $values{$key}->[0];
        $endref->{$key} = $values{$key}->[1];
      }
    } else {
      my %values = read_jcmtstate( $first, 'start' );
      %$startref = %values;
      %values = read_jcmtstate( $last, 'end' );
      %$endref = %values;
    }
  } catch JSA::Error with {
    $E = shift;
  };

  if (defined $E) {
    $E->flush if defined $E;
    orac_warn( "Unable to read JCMTSTATE.$keyword from input file\n" );
  }

  return $self->{JCMTSTATE}->{$which}->{$keyword};
}

=item B<find_base_position>

Determine the base position of a data file. If the file name
is not provided it will be read from the object.

  %base = $Frm->find_base_position( $file );

Returns hash with keys

  TCS_TR_SYS   Tracking system for base
  TCS_TR_BC1   Longitude of base position (radians)
  TCS_TR_BC2   Latitude of base position (radians)

The latter will be absent if this is an observation of a moving
source. In addition, returns sexagesimal strings of the base
position as

  TCS_TR_BC1_STR
  TCS_TR_BC2_STR

=cut

sub find_base_position {
  my $self = shift;
  my $file = shift;
  $file = $self->file unless defined $file;

  my %state;

  # First read the FITS header (assume that TRACKSYS presence implies BASEC1/C2)
  if (defined $self->hdr("TRACKSYS") ) {
    $state{TCS_TR_SYS} = $self->hdr("TRACKSYS");

    if ($state{TCS_TR_SYS} ne 'APP') {

      # Now we have to look for BASEC1 which might be missing
      # in the first subheader (DARK or FASTFLAT)
      my $hdr = $self->hdr;
      my $nsubheaders = 1;
      $nsubheaders = scalar @{$hdr->{SUBHEADERS}}
        if exists $hdr->{SUBHEADERS};

      my %base;
      for my $i (0..$nsubheaders-1) {
        my $basec1 = $self->hdrval( "BASEC1", $i );
        next unless (defined $basec1 && length($basec1) > 0);
        my $basec2 = $self->hdrval( "BASEC2", $i );
        if (defined $basec2 && length($basec2) > 0) {
          $base{C1} = $basec1;
          $base{C2} = $basec2;
        }
      }

      if (exists $base{C1} && exists $base{C2}) {
        # converting degrees to radians
        for my $c (qw/ C1 C2 /) {
          my $ang = Astro::Coords::Angle->new( $base{$c}, units => "deg");
          $state{"TCS_TR_B$c"} = $ang->radians;
        }
      }
    }
  } else {
    # Attempt to read from JCMTSTATE
    try {
      $state{TCS_TR_SYS} = $self->jcmtstate( "TCS_TR_SYS" );
      if (defined $state{TCS_TR_SYS} && $state{TCS_TR_SYS} ne 'APP') {
        for my $i (qw/ TCS_TR_BC1 TCS_TR_BC2 / ) {
          $state{$i} = $self->jcmtstate( $i );
        }
      }
    };

    # if that doesn't work we probably have SCUBA-2 processed images
    # or some very odd ACSIS files
    if (!exists $state{TCS_TR_SYS}) {
      # need the WCS
      my $wcs = $self->read_wcs( $file );

      # if no WCS read, attempt to read it from FITS headers
      # QL images use this technique. Need the raw header, not a merged one
      if (!defined $wcs) {
        my $fits = Astro::FITS::Header::NDF->new( File => $file );
        $wcs = $fits->get_wcs;
      }

      if (defined $wcs) {
        # Find a Sky frame
        my $skytemplate = Starlink::AST::SkyFrame->new( "MaxAxes=3,MinAxes=1" );
        my $skyframe = $wcs->FindFrame( $skytemplate, "" );

        if (defined $skyframe) {
          # Get the sky reference position and system
          my $astsys = $wcs->Get("System");
          if ( exists $astToJCMT{$astsys}) {
            $state{TCS_TR_SYS} = $astToJCMT{$astsys};
          } else {
            warnings::warnif("Could not understand coordinate frame $astsys. Using ICRS");
            $state{TCS_TR_SYS} = "ICRS";
          }

          if ($state{TCS_TR_SYS} ne "APP") {
            $state{TCS_TR_BC1} = $wcs->Get("SkyRef(1)");
            $state{TCS_TR_BC2} = $wcs->Get("SkyRef(2)");
          }
        } else {
          # look for a specframe
          my $spectemplate = Starlink::AST::SpecFrame->new( "MaxAxes=3" );
          my $findspecfs = $wcs->FindFrame( $spectemplate, ",," );
          my $specframe = $findspecfs->GetFrame( 2 );
          ($state{TCS_TR_BC1}, $state{TCS_TR_BC2}) =
            $specframe->GetRefPos( Starlink::AST::SkyFrame->new("System=J2000") );
          $state{TCS_TR_SYS} = "J2000"; # by definition
        }
      }
    }
  }

  # Group allocation is normalised to ICRS coordinates so we need the base
  # position in ICRS.
  if (exists $state{TCS_TR_SYS} && exists $state{TCS_TR_BC1} && exists $state{TCS_TR_BC2}) {
    my $obsra;
    my $obsdec;
    if ($state{TCS_TR_SYS} eq 'ICRS') {
      $obsra = $state{TCS_TR_BC1};
      $obsdec = $state{TCS_TR_BC2};
    } else {
      # Use AST to convert
      my $astsys = ( exists $JCMTToAst{$state{TCS_TR_SYS}} ? $JCMTToAst{$state{TCS_TR_SYS}} : undef );
      if (defined $astsys) {
        my $skyframe = Starlink::AST::SkyFrame->new( "System=$astsys");
        $skyframe->Set("skyref(1)=". $state{TCS_TR_BC1});
        $skyframe->Set("skyref(2)=". $state{TCS_TR_BC2});
        $skyframe->Set("system=ICRS");
        $obsra = $skyframe->Get("SkyRef(1)");
        $obsdec = $skyframe->Get("SkyRef(2)");
      } else {
        warnings::warnif("Could not understand coordinate frame $state{TCS_TR_SYS}. Assuming we are okay with BC1 and BC2");
        $obsra = $state{TCS_TR_BC1};
        $obsdec = $state{TCS_TR_BC2};
      }
    }
    $state{TCS_TR_NORM1} = $obsra;
    $state{TCS_TR_NORM2} = $obsdec;
  }

  # See if we managed to read a tracking system
  if (!exists $state{TCS_TR_SYS}) {
    croak "Completely unable to read a tracking system from file $file !!!\n";
  }

  # if we have base positions, create string versions
  if (exists $state{TCS_TR_NORM1} && exists $state{TCS_TR_NORM2} ) {
    for my $c (qw/ 1 2 /) {
      my $class = "Astro::Coords::Angle" . ($c == 1 ? "::Hour" : "");
      my $ang = $class->new( $state{"TCS_TR_NORM$c"},
                             units => 'rad' );
      $ang->str_ndp(0); # no decimal places
      $ang = $ang->string;
      $ang =~ s/\D//g; # keep numbers
      $state{"TCS_TR_BC$c"."_STR"} = $ang;
    }
  }

  return %state;
}

=item B<findgroup>

Returns the group name from the header or a string formed automatically
on observation metadata.

 $Frm->findgroup();

An optional argument can be provided which will be appended to the group
name. This can be used by subclasses to provide additional information
required to disambiguate groups. This string is only used if the group
identifier is not present in the DRGROUP header.

 $Frm->findgroup( $string );

The group name stored in the object is automatically update using this
value.

=cut

sub findgroup {
  my $self = shift;
  my $extra = shift;

  my $hdrgrp;
  # Use value in header if present
  if (exists $self->hdr->{DRGROUP} && defined $self->hdr->{DRGROUP}
      && $self->hdr->{DRGROUP} ne 'UNKNOWN'
      && $self->hdr->{DRGROUP} =~ /\w/) {
    $hdrgrp = $self->hdr->{DRGROUP};
  } else {
    # Create our own DRGROUP string
    # Read the base position information from the file
    my %state = $self->find_base_position();
    if (exists $state{TCS_TR_BC1_STR} && exists $state{TCS_TR_BC2_STR}) {
      # Define group key based on stringified form of TCS base position
      $hdrgrp = $state{TCS_TR_BC1_STR} . $state{TCS_TR_BC2_STR};

    } else {
      # We're tracking in geocentric apparent, so instead of using the
      # RefRA/RefDec position (which will be moving with the object)
      # use the object name.
      $hdrgrp = $self->hdr( "OBJECT" );
    }

    # JCMT disambiguates on these headers
    # Note that we normalize RASTER and SCAN mode for historical data
    $hdrgrp .=
      ( uc( $self->hdr( "SAM_MODE" ) ) eq 'RASTER' ? 'SCAN' : uc( $self->hdr( "SAM_MODE" ) ) ) .
        $self->hdr( "SW_MODE" ) .
          $self->hdr( "INSTRUME" ) .
            $self->hdr( "OBS_TYPE" ) .
                $self->hdr( "SIMULATE" );

    # Add DATE-OBS if we're not doing a science observation.
    # to ensure that they are not combined into groups
    if( uc( $self->hdr( "OBS_TYPE" ) ) ne 'SCIENCE' ) {
      $hdrgrp .= $self->hdr( "OBSID" );
    }

    # Add any extra information from subclass
    $hdrgrp .= $extra if defined $extra;

  }

  # Update the group
  $self->group($hdrgrp);

  return $hdrgrp;
}

=item B<findnsubs>

Find the number of sub-frames associated by the frame by looking
at the list of raw files associated with object. Usually run
by configure().

  $nsubs = $Frm->findnsubs;

The state of the object is updated automatically.

=cut

sub findnsubs {
  my $self = shift;
  my @files = $self->raw;
  my $nsubs = scalar( @files );
  $self->nsubs( $nsubs );
  return $nsubs;
}

=back

=begin __PROTECTED_METHODS__

=head1 PROTECTED METHODS

These methods are for subclasses.

=over 4

=item B<_padnum>

Pad an observation number.

 $padded = $frm->_padnum( $raw );

=cut

sub _padnum {
  my $self = shift;
  my $raw = shift;
  return sprintf( "%05d", $raw);
}

=back

=end __PROTECTED_METHODS__

=head1 SEE ALSO

L<ORAC::Group>, L<ORAC::Frame::NDF>, L<ORAC::Frame>

=head1 AUTHORS

Brad Cavanagh <b.cavanagh@jach.hawaii.edu>
Tim Jenness <t.jenness@jach.hawaii.edu>

=head1 COPYRIGHT

Copyright (C) 2009 Science and Technology Facilities Council. All
Rights Reserved.

=cut

1;
