package ORAC::Calib::SWFCAM;

=head1 NAME

ORAC::Calib::SWFCAM;

=head1 SYNOPSIS

use ORAC::Calib::SWFCAM;

  $Cal = new ORAC::Calib::SWFCAM;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

=head1 DESCRIPTION

This module contains methods for specifying WFCAM-specific calibration
objects when using Starlink software for reduction. It provides a class
derived from ORAC::Calib. All the methods available to ORAC::Calib objects
are available to ORAC::Calib::SWFCAM objects.

=cut

use Carp;
use warnings;
use strict;

use ORAC::Calib::UFTI;
use ORAC::Print;

use File::Spec;

use base qw/ ORAC::Calib::UFTI /;

use vars qw/ $VERSION /;
'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

=head1 METHODS

The following methods are available:

=head2 Constructor

=over 4

=item B<new>

Sub-classed constructor. Adds knowledge of interleave mask.

  my $Cal = new ORAC::Calib::SWFCAM;

=cut

sub new {
  my $self = shift;
  my $obj = $self->SUPER::new(@_);

# Assumes we have a hash object.
  $obj->{InterleaveMask} = undef;
  $obj->{InterleaveMaskIndex} = undef;
  $obj->{InterleaveMaskNoUpdate} = 0;

  return $obj;
}

=back

=head2 Accessors

=over 4

=item B<interleavemaskname>

Return (or set) the mask used in the interleaving process.

  $interleavemask = $Cal->interleavemaskname;

=cut

sub interleavemaskname {
  my $self = shift;

  if( @_ ) { $self->{InterleaveMask} = shift unless $self->interleavemasknoupdate; }
  return $self->{InterleaveMask};
}

=item B<interleavemaskindex>

Return or set the index object associated with the interleave mask.

  $index = $Cal->interleavemaskindex;

An index object is created automatically the first time this method
is run.

=cut

sub interleavemaskindex {
  my $self = shift;
  if ( @_ ) { $self->{InterleaveMaskIndex} = shift; }
  unless ( defined $self->{InterleaveMaskIndex} ) {
    my $indexfile = $self->find_file("index.interleavemask");
    my $rulesfile = $self->find_file("rules.interleavemask");
    $self->{InterleaveMaskIndex} = new ORAC::Index( $indexfile, $rulesfile );
  }
  return $self->{InterleaveMaskIndex};
}

=item B<interleavemasknoupdate>

Stops object from updating itself with more recent data.
Used when overriding the interleave mask from the commandline.

=cut

sub interleavemasknoupdate {
  my $self = shift;
  if( @_ ) { $self->{InterleaveMaskNoUpdate} = shift; }
  return $self->{InterleaveMaskNoUpdate};
}

=back

=head2 General Methods

=over 4

=item B<interleavemask>

Determine the mask necessary for microstep interleaving.

  $interleavemask = $Cal->interleavemask;

This method returns a filename, including directory structure. If
the noupdate flag is set there is no verification that the mask
meets the specified rules.

=cut

sub interleavemask {
  my $self = shift;

# Handle arguments.
  return $self->interleavemaskname(shift) if @_;

  my $ok = $self->interleavemaskindex->verify( $self->interleavemaskname, $self->thing );

  if( $ok ) { return $self->interleavemaskname };

  croak("Override interleave mask is not suitable! Giving up") if $self->interleavemasknoupdate;

  if( defined( $ok ) ) {
    my $mask = $self->interleavemaskindex->choosebydt('ORACTIME', $self->thing);
    croak "No suitable interleave mask calibration was found in index file"
      unless defined $mask;
    $self->interleavemaskname($mask);
  } else {
    croak "Error in interleave mask calibration checking - giving up";
  }
}

=back

=head1 REVISION

$Id$

=head1 AUTHORS

Brad Cavangh (b.cavanagh@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 2004 Particle Physics and Astronomy Research
Council.  All Rights Reserved.

=cut

1;
