package ORAC::Calib::ACSIS;

=head1 NAME

ORAC::Calib::ACSIS;

=head1 SYNOPSIS

  use ORAC::Calib::ACSIS;

  $Cal = new ORAC::Calib::ACSIS;

=head1 DESCRIPTION

This module contains methods for specifying ACSIS-specific calibration
objects. It provides a class derived from ORAC::Calib. All the methods
available to ORAC::Calib objects are also available to
ORAC::Calib::ACSIS objects.

=cut

use Carp;
use warnings;
use strict;

use ORAC::Print;

use File::Copy;
use File::Spec;

use base qw/ ORAC::Calib /;

use vars qw/ $VERSION /;
'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

=head1 METHODS

The following methods are available:

=head2 Constructor

=over 4

=item B<new>

Sub-classed constructor. Adds knowledge of pointing, reference
spectrum, beam efficiency, and other ACSIS-specific calibration
information.

=cut

sub new {
  my $self = shift;
  my $obj = $self->SUPER::new( @_ );

# This assumes we have a hash object.
  $obj->{BadReceptors} = undef;
  $obj->{BadReceptorsIndex} = undef;
  $obj->{BadReceptorsNoUpdate} = 0;
  $obj->{Pointing} = undef;
  $obj->{PointingIndex} = undef;
  $obj->{PointingNoUpdate} = 0;
  $obj->{QAParams} = undef;
  $obj->{QAParamsIndex} = undef;
  $obj->{QAParamsNoUpdate} = 0;

  return $obj;
}

=back

=head2 Accessors

=over 4

=item B<bad_receptors>

Set or retrieve the name of the system to be used for bad receptor
determination. Allowed values are:

=over 4

=item * master

Use the master index.bad_receptors index file in $ORAC_DATA_CAL.

=item * index

Use the index.bad_receptors_qa index file in $ORAC_DATA_OUT as
generated by the pipeline.

=item * indexormaster

Use both the master index.bad_receptors and pipeline-generated
index.bad_receptors_qa file. Results are 'or'ed together, so any
receptors flagged as bad in either index file will be flagged as bad.

=item * file

Use the contents of the file F<bad_receptors.lis>, which contains a
space-separated list of receptor names in the first line. This file
must be found in $ORAC_DATA_OUT. If the file cannot be found, no
receptors will be flagged.

=item * 'list'

A colon-separated list of receptor names can be supplied.

=back

The default is to use the 'indexormaster' method. The returned value
will always be in upper-case.

=cut

sub bad_receptors {
  my $self = shift;

  if( @_ ) { $self->{BadReceptors} = uc( shift ) unless $self->bad_receptors_noupdate; }
  $self->{BadReceptors} = 'INDEXORMASTER' unless ( defined $self->{BadReceptors} );
  return $self->{BadReceptors};
}

=item B<bad_receptors_index>

Return (or set) the index object associated with the master bad
receptors index file. This index file is used if bad_receptors() is
set to 'MASTER' or 'INDEXORMASTER'.

=cut

sub bad_receptors_index {
  my $self = shift;
  if( @_ ) { $self->{BadReceptorsIndex} = shift; }

  if( ! defined( $self->{BadReceptorsIndex} ) ) {

    my $indexfile = File::Spec->catfile( $ENV{'ORAC_DATA_CAL'}, "index.bad_receptors" );
    my $rulesfile = $self->find_file( "rules.bad_receptors" );

    $self->{BadReceptorsIndex} = new ORAC::Index( $indexfile, $rulesfile );
  }

  return $self->{BadReceptorsIndex};
}

=item B<bad_receptors_qa_index>

Return (or set) the index object associated with the
pipeline-generated bad receptors index file. This index file is used
if bad_receptors() is set to 'INDEX' or 'INDEXORMASTER'.

=cut

sub bad_receptors_qa_index {
  my $self = shift;
  if( @_ ) { $self->{BadReceptorsQAIndex} = shift; }

  if( ! defined( $self->{BadReceptorsQAIndex} ) ) {

    my $indexfile = File::Spec->catfile( $ENV{'ORAC_DATA_OUT'}, "index.bad_receptors_qa" );
    my $rulesfile = $self->find_file( "rules.bad_receptors_qa" );

    $self->{BadReceptorsQAIndex} = new ORAC::Index( $indexfile, $rulesfile );
  }

  return $self->{BadReceptorsQAIndex};
}

=item B<bad_receptors_noupdate>

Flag to prevent the bad_receptors system from being modified during
data processing.

=cut

sub bad_receptors_noupdate {
  my $self = shift;
  if( @_ ) { $self->{BadReceptorsNoUpdate} = shift; }
  return $self->{BadReceptorsNoUpdate};
}

=item B<bad_receptors_list>

Return a list of receptor names that should be masked as bad for the
current observation. The source of this list depends on the setting of
the badbols() accessor.

=cut

sub bad_receptors_list {
  my $self = shift;

  # Retrieve the bad_receptors query system.
  my $sys = $self->bad_receptors;

  # Array to hold the bad receptors.
  my @bad_receptors = ();

  # Go through each system.
  if( $sys eq 'INDEX' or $sys eq 'MASTER' or $sys eq 'INDEXORMASTER' ) {

    # We need to set up some temporary headers for LOFREQ_MIN and
    # LOFREQ_MAX. The "thing" method contains the merged uhdr and hdr,
    # so just stick them in there. The uhdr is in "thingtwo".
    my $lofreq = $self->thing->{'LOFREQS'};
    my $thing2 = $self->thingtwo;
    $thing2->{'LOFREQ_MIN'} = $lofreq;
    $thing2->{'LOFREQ_MAX'} = $lofreq;
    $self->thingtwo( $thing2 );

    my @master_bad = ();
    my @index_bad = ();

    if( $sys =~ /MASTER/ ) {

      my $brposition = $self->bad_receptors_index->chooseby_negativedt( 'ORACTIME', $self->thing, 0 );

      if( defined( $brposition ) ) {
        # Retrieve the specific entry, and thus the receptors.
        my $brref = $self->bad_receptors_index->indexentry( $brposition );
        if( exists( $brref->{'DETECTORS'} ) ) {
          @master_bad = split /,/, $brref->{'DETECTORS'};
        } else {
          croak "Unable to obtain DETECTORS from master index file entry $brposition\n";
        }
      }
    }

    if ( $sys =~ /INDEX/ ) {

      # This one also has a modified SURVEY_BR, so set that based on
      # the SURVEY header.
      my $survey = $self->thing->{'SURVEY'};
      my $thing2 = $self->thingtwo;
      if( ! defined( $thing2->{'SURVEY_BR'} ) ) {
        if( defined( $survey ) ) {
          $thing2->{'SURVEY_BR'} = $survey;
        } else {
          $thing2->{'SURVEY_BR'} = 'Telescope';
        }
        $self->thingtwo( $thing2 );
      }

      my $brposition = $self->bad_receptors_qa_index->choosebydt( 'ORACTIME', $self->thing, 0 );

      if( defined( $brposition ) ) {
        # Retrieve the specific entry, and thus the receptors.
        my $brref = $self->bad_receptors_qa_index->indexentry( $brposition );
        if( exists( $brref->{'DETECTORS'} ) ) {
          @index_bad = split /,/, $brref->{'DETECTORS'};
        } else {
          croak "Unable to obtain DETECTORS from QA index file entry $brposition\n";
        }
      }

    }

    # Remove the temporary LOFREQ_MIN and LOFREQ_MAX headers.
    $thing2 = $self->thingtwo;
    delete $thing2->{'LOFREQ_MIN'};
    delete $thing2->{'LOFREQ_MAX'};
    $self->thingtwo( $thing2 );

    # Merge the master and QA bad receptors.
    my %seen = map { $_, 1 } @master_bad, @index_bad;
    @bad_receptors = keys %seen;

  } elsif( $sys eq 'FILE' ) {

    # Look for bad receptors in the bad_receptors.lis file.
    my $file = File::Spec->catfile( $ENV{'ORAC_DATA_OUT'}, "bad_receptors.lis" );
    if( -e $file ) {
      my $fh = new IO::File( "< $file" );
      if( defined( $fh ) ) {
        my $list = <$fh>;
        close $fh;
        @bad_receptors = split( /\s+/, $list );
      }
    }

  } else {

    # Look for bad receptors in $sys itself.
    @bad_receptors = split /:/, $sys;
  }

  return @bad_receptors;
}

=item B<pointing>

Return (or set) the most recent pointing values.

  $pointing = $Cal->pointing;

=cut

sub pointing {
  my $self = shift;

  # Handle arguments.
  return $self->pointingcache( shift ) if @_;

  if( $self->pointingnoupdate ) {
    my $cache = $self->pointingcache;
    return $cache if defined $cache;
  }

  my $pointingfile = $self->pointingindex->choosebydt( 'ORACTIME', $self->thing );
  if( ! defined( $pointingfile ) ) {
    croak "No suitable pointing value found in index file"
  }

  my $pointingref = $self->pointingindex->indexentry( $pointingfile );
  if( exists( $pointingref->{DAZ} ) &&
      exists( $pointingref->{DEL} ) ) {
    return $pointingref;
  } else {
    croak "Unable to obtain DAZ and DEL from index file entry $pointingfile\n";
  }

}

=item B<pointingcache>

Cached value of the pointing. Only used when noupdate is in effect.

=cut

sub pointingcache {
  my $self = shift;
  if( @_ ) { $self->{Pointing} = shift unless $self->pointingnoupdate; }
  return $self->{Pointing};
}

=item B<pointingnoupdate>

Stops pointing object from updating itself with more recent data.

Used when using a command-line override to the pipeline.

=cut

sub pointingnoupdate {
  my $self = shift;
  if( @_ ) { $self->{PointingNoUpdate} = shift; }
  return $self->{PointingNoUpdate};
}

=item B<pointingindex>

Return (or set) the index object associated with the pointing index
file.

=cut

sub pointingindex {
  my $self = shift;
  if( @_ ) { $self->{PointingIndex} = shift; }

  if( ! defined( $self->{PointingIndex} ) ) {
    my $indexfile = File::Spec->catfile( $ENV{'ORAC_DATA_OUT'}, "index.pointing" );
    my $rulesfile = $self->find_file( "rules.pointing" );
    if( ! defined( $rulesfile ) ) {
      croak "pointing rules file could not be located\n";
    }
    $self->{PointingIndex} = new ORAC::Index( $indexfile, $rulesfile );
  }

  return $self->{PointingIndex};

}

=item B<qaparams>

Return or set the filename for QA parameters.

  my $qaparams = $Cal->qaparams;

=cut

sub qaparams {
  my $self = shift;

  # Handle arguments.
  return $self->qaparamscache( shift ) if @_;

  if( $self->qaparamsnoupdate ) {
    my $cache = $self->qaparamscache;
    return $cache if defined $cache;
  }

  my $qaparamsfile = $self->qaparamsindex->choosebydt( 'ORACTIME', $self->thing );
  if( ! defined( $qaparamsfile ) ) {
    croak "No suitable QA parameters file found in index file"
  }

  return File::Spec->catfile( $ENV{'ORAC_DATA_CAL'}, $qaparamsfile );

}

=item B<qaparamscache>

Cached value for the QA parameters file. Only used when noupdate is in
effect.

=cut

sub qaparamscache {
  my $self = shift;
  if( @_ ) { $self->{QAParams} = shift unless $self->qaparamsnoupdate; }
  return $self->{QAParams};
}

=item B<qaparamsnoupdate>

Stops QA params object from updating itself.

Used when using a command-line override to the pipeline.

=cut

sub qaparamsnoupdate {
  my $self = shift;
  if( @_ ) { $self->{QAParamsNoUpdate} = shift; }
  return $self->{QAParamsNoUpdate};
}

=item B<qaparamsindex>

Return or set the index object associated with the QA parameters index
file.

=cut

sub qaparamsindex {
  my $self = shift;
  if( @_ ) { $self->{QAParamsIndex} = shift; }

  if( ! defined( $self->{QAParamsIndex} ) ) {
    my $indexfile = $self->find_file( "index.qaparams" );
    if( ! defined( $indexfile ) ) {
      croak "QA parameters index file could not be located\n";
    }
    my $rulesfile = $self->find_file( "rules.qaparams" );
    if( ! defined( $rulesfile ) ) {
      croak "QA parameters rules file could not be located\n";
    }
    $self->{QAParamsIndex} = new ORAC::Index( $indexfile, $rulesfile );
  }

  return $self->{QAParamsIndex};
}

=back

=head1 REVISION

$Id$

=head1 AUTHORS

Brad Cavanagh <b.cavanagh@jach.hawaii.edu>

=head1 COPYRIGHT

Copyright (C) 2007-2008 Science and Technology Facilities Council.
All Rights Reserved.

=cut

1;
