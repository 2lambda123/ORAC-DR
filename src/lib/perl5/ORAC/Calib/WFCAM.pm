package ORAC::Calib::WFCAM;

=head1 NAME

ORAC::Calib::WFCAM;

=head1 SYNOPSIS

  use ORAC::Calib::WFCAM;

  $Cal = new ORAC::Calib::WFCAM;

  $dark = $Cal->dark;
  $Cal->dark("darkname");

  $Cal->standard(undef);
  $standard = $Cal->standard;
  $readnoise = $Cal->readnoise;

=head1 DESCRIPTION

This module contains methods for specifying WFCAM-specific calibration
objects. It provides a class derived from ORAC::Calib.  All the
methods available to ORAC::Calib objects are available to
ORAC::Calib::WFCAM objects.

=cut

use ORAC::Calib;			# use base class
use ORAC::Print;

use base qw/ORAC::Calib/;

use vars qw/$VERSION/;
'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# @ORAC::Calib::WFCAM::ISA = qw/ORAC::Calib/; # set up inheritance

# standard error module and turn on strict
use Carp;
use strict;

use File::Spec;

=head1 METHODS

The following methods are available:

=head2 Constructor

=over 4

=item B<new>

Sub-classed constructor. Adds knowledge of linearity and confidence maps.

  my $Cal = new ORAC::Calib::WFCAM;

=cut

sub new {
    my $self = shift;
    my $obj = $self->SUPER::new(@_);

    # Assumes we have a hash object

    $obj->{BPM} = undef;
    $obj->{BPMIndex} = undef;
    $obj->{BPMNoUpdate} = 0;
    $obj->{CPM} = undef;
    $obj->{CPMIndex} = undef;
    $obj->{CPMNoUpdate} = 0;
    $obj->{Dome} = undef;
    $obj->{DomeIndex} = undef;
    $obj->{DomeNoUpdate} = 0;
    $obj->{Lintab} = undef;
    $obj->{LintabIndex} = undef;
    $obj->{LintabNoUpdate} = 0;
    $obj->{DQCIndex} = undef;
    $obj->{Photom} = undef;
    $obj->{PhotomIndex} = undef;
    $obj->{PhotomNoUpdate} = 0;
    $obj->{Astrom} = undef;
    $obj->{AstromIndex} = undef;
    $obj->{AstromNoUpdate} = 0;
  
    return $obj;

}


=back

=head2 Accessors

=over 4

=item B<lintabname>

Return (or set) the name of the current linearity curve

  $mask = $Cal->lintabname;

The C<lintab()> method should be used if a test for suitability of the
linearity table is required.

=cut


sub lintabname {
    my $self = shift;
    if (@_) { $self->{Lintab} = shift unless $self->lintabnoupdate; }
    return $self->{Lintab}; 
}


=item B<lintabindex>

Return or set the index object associated with the linearity table

  $index = $Cal->lintabindex;

An index object is created automatically the first time this method
is run.

=cut

sub lintabindex {

  my $self = shift;
  if (@_) { $self->{LintabIndex} = shift; }
  unless (defined $self->{LintabIndex}) {
    my $indexfile = File::Spec->catfile($ENV{'ORAC_DATA_OUT'},"index.lintab");
    my $rulesfile = $self->find_file("rules.lintab");
    $self->{LintabIndex} = new ORAC::Index($indexfile,$rulesfile);
  }

  return $self->{LintabIndex};

}

=item B<lintabnoupdate>

Stops object from updating itself with more recent data.
Used when overrding the linearity table from the command-line.

=cut

sub lintabnoupdate {

    my $self = shift;
    if (@_) { $self->{LintabNoUpdate} = shift; }
    return $self->{LintabNoUpdate};

}

=item B<domename>

Return (or set) the name of the current dome flat

  $mask = $Cal->domename;

The C<dome()> method should be used if a test for suitability of the
bad pixel mask is required.

=cut


sub domename {
    my $self = shift;
    if (@_) { $self->{Dome} = shift unless $self->domenoupdate; }
    return $self->{Dome}; 
};

=item B<domeindex>

Return or set the index object associated with the dome flat field

  $index = $Cal->domeindex;

An index object is created automatically the first time this method
is run.

=cut

sub domeindex {

  my $self = shift;
  if (@_) { $self->{DomeIndex} = shift; }
  unless (defined $self->{DomeIndex}) {
    my $indexfile = File::Spec->catfile($ENV{'ORAC_DATA_OUT'},"index.dome");
    my $rulesfile = $self->find_file("rules.dome");
    $self->{DomeIndex} = new ORAC::Index($indexfile,$rulesfile);
  }

  return $self->{DomeIndex};

}

=item B<domenoupdate>

Stops object from updating itself with more recent data.
Used when overrding the dome flat from the command-line.

=cut

sub domenoupdate {

    my $self = shift;
    if (@_) { $self->{DomeNoUpdate} = shift; }
    return $self->{DomeNoUpdate};

}

=item B<BPMname>

Return (or set) the name of the current bad pixel mask

  $mask = $Cal->BPMname;

The C<BPM()> method should be used if a test for suitability of the
bad pixel mask is required.

=cut


sub BPMname {
    my $self = shift;
    if (@_) { $self->{BPM} = shift unless $self->BPMnoupdate; }
    return $self->{BPM}; 
};


=item B<BPMindex>

Return or set the index object associated with the bad pixel mask

  $index = $Cal->BPMindex;

An index object is created automatically the first time this method
is run.

=cut

sub BPMindex {

  my $self = shift;
  if (@_) { $self->{BPMIndex} = shift; }
  unless (defined $self->{BPMIndex}) {
    my $indexfile = File::Spec->catfile($ENV{'ORAC_DATA_OUT'},"index.bpm");
    my $rulesfile = $self->find_file("rules.bpm");
    $self->{BPMIndex} = new ORAC::Index($indexfile,$rulesfile);
  }

  return $self->{BPMIndex};

}

=item B<BPMnoupdate>

Stops object from updating itself with more recent data.
Used when overrding the bad pixel mask from the command-line.

=cut

sub BPMnoupdate {

    my $self = shift;
    if (@_) { $self->{BPMNoUpdate} = shift; }
    return $self->{BPMNoUpdate};

}

=item B<CPMname>

Return (or set) the name of the current confidence map.

  $mask = $Cal->CPMname;

The C<CPM()> method should be used if a test for suitability of the
confidence map is required.

=cut


sub CPMname {
    my $self = shift;
    if (@_) { $self->{CPM} = shift unless $self->CPMnoupdate; }
    return $self->{CPM}; 
};


=item B<CPMindex>

Return or set the index object associated with the confidence map

  $index = $Cal->CPMindex;

An index object is created automatically the first time this method
is run.

=cut

sub CPMindex {

  my $self = shift;
  if (@_) { $self->{CPMIndex} = shift; }
  unless (defined $self->{CPMIndex}) {
    my $indexfile = File::Spec->catfile($ENV{'ORAC_DATA_OUT'},"index.cpm");
    my $rulesfile = $self->find_file("rules.cpm");
    $self->{CPMIndex} = new ORAC::Index($indexfile,$rulesfile);
  }

  return $self->{CPMIndex};

}

=item B<CPMnoupdate>

Stops object from updating itself with more recent data.
Used when overrding the confidence map from the command-line.

=cut

sub CPMnoupdate {

    my $self = shift;
    if (@_) { $self->{CPMNoUpdate} = shift; }
    return $self->{CPMNoUpdate};

}

=item B<photomname>

Return (or set) the name of the current photometric standard source.

  $photom = $Cal->photomname;


=cut


sub photomname {
    my $self = shift;
    if (@_) { $self->{Photom} = shift unless $self->photomnoupdate; }
    return $self->{Photom}; 
};

=item B<photomindex>

Return or set the index object associated with the photometry source

  $index = $Cal->photomindex;

An index object is created automatically the first time this method
is run.

=cut

sub photomindex {

  my $self = shift;
  if (@_) { $self->{PhotomIndex} = shift; }
  unless (defined $self->{PhotomIndex}) {
    my $indexfile = File::Spec->catfile($ENV{'ORAC_DATA_OUT'},"index.photom");
    my $rulesfile = $self->find_file("rules.photom");
    $self->{PhotomIndex} = new ORAC::Index($indexfile,$rulesfile);
  }

  return $self->{PhotomIndex};

}


=item B<photomnoupdate>

Stops object from updating itself with more recent data.
Used when overrding the default photometry source from the command-line.

=cut

sub photomnoupdate {

    my $self = shift;
    if (@_) { $self->{PhotomNoUpdate} = shift; }
    return $self->{PhotomNoUpdate};

}

=back

=item B<astromname>

Return (or set) the name of the current astrometric standard source.

  $astrom = $Cal->astromname;


=cut


sub astromname {
    my $self = shift;
    if (@_) { $self->{Astrom} = shift unless $self->astromnoupdate; }
    return $self->{Astrom}; 
};

=item B<astromindex>

Return or set the index object associated with the astrometry source

  $index = $Cal->astromindex;

An index object is created automatically the first time this method
is run.

=cut

sub astromindex {

  my $self = shift;
  if (@_) { $self->{AstromIndex} = shift; }
  unless (defined $self->{AstromIndex}) {
    my $indexfile = File::Spec->catfile($ENV{'ORAC_DATA_OUT'},"index.astrom");
    my $rulesfile = $self->find_file("rules.astrom");
    $self->{AstromIndex} = new ORAC::Index($indexfile,$rulesfile);
  }

  return $self->{AstromIndex};

}


=item B<astromnoupdate>

Stops object from updating itself with more recent data.
Used when overrding the default astrometry source from the command-line.

=cut

sub astromnoupdate {

    my $self = shift;
    if (@_) { $self->{AstromNoUpdate} = shift; }
    return $self->{AstromNoUpdate};

}

=item B<dqcindex>

Return or set the index object associated with the DQC table

  $index = $Cal->dqcindex;

An index object is created automatically the first time this method
is run.

=cut

sub dqcindex {

  my $self = shift;
  if (@_) { $self->{DQCIndex} = shift; }
  unless (defined $self->{DQCIndex}) {
    my $indexfile = File::Spec->catfile($ENV{'ORAC_DATA_OUT'},"index.dqc");
    my $rulesfile = $self->find_file("rules.dqc");
    $self->{DQCIndex} = new ORAC::Index($indexfile,$rulesfile);
  }

  return $self->{DQCIndex};

}

=back

=head2 General Methods

=over 4

=item B<lintab>

Return (or set) the name of the current linearity table. If a table is to be 
returned every effort is made to guarantee that it is suitable for use.

  $lintab = $Cal->lintab;
  $Cal->lintab($newlintab);

=cut


sub lintab {

    my $self = shift;

    if (@_) {
        return $self->lintabname(shift);
    };

    my $ok = $self->lintabindex->verify($self->lintabname,$self->thing);

    # happy ending

    return $self->lintabname if $ok;

    croak ("Override linearity table is not suitable! Giving up") 
        if $self->lintabnoupdate;

    if (defined $ok) {
        my $lintab = $self->lintabindex->choosebydt('ORACTIME',$self->thing);
        if (! defined $lintab) {
            croak "No suitable linearity table was found in index file";
        }

        # Store the good value

        $self->lintabname($lintab);

    } else {

        # All fall down....

        croak("Error in determining linearity table - giving up");
    }
}

=item B<dome>

Return (or set) the name of the current dome flat. If a map is to be 
returned every effort is made to guarantee that it is suitable for use.

  $dome = $Cal->dome;
  $Cal->dome($newdome);

=cut


sub dome {

    my $self = shift;

    if (@_) {
        return $self->domename(shift);
    };

    my $ok = $self->domeindex->verify($self->domename,$self->thing,0);

    # happy ending

    return $self->domename if $ok;

    croak ("Override domeflat is not suitable! Giving up") 
        if $self->domenoupdate;

    if (defined $ok) {
        my $dome = $self->domeindex->choosebydt('ORACTIME',$self->thing,0);
        if (! defined $dome) {
            croak "No suitable confidence map was found in index file";
        }

        # Store the good value

        $self->domename($dome);

    } else {

        # All fall down....

        croak("Error in determining confidence map - giving up");
    }
}

=item B<BPM>

Return (or set) the name of the current bad pixel mask. If a map is to be 
returned every effort is made to guarantee that it is suitable for use.

  $bpm = $Cal->BPM;
  $Cal->BPM($newBPM);

=cut


sub BPM {

    my $self = shift;

    if (@_) {
        return $self->BPMname(shift);
    };

    my $ok = $self->BPMindex->verify($self->BPMname,$self->thing,0);

    # happy ending

    return $self->BPMname if $ok;

    croak ("Override confidence map is not suitable! Giving up") 
        if $self->BPMnoupdate;

    if (defined $ok) {
        my $bpm = $self->BPMindex->choosebydt('ORACTIME',$self->thing,0);
        if (! defined $bpm) {
            croak "No suitable confidence map was found in index file";
        }

        # Store the good value

        $self->BPMname($bpm);

    } else {

        # All fall down....

        croak("Error in determining confidence map - giving up");
    }
}

=item B<CPM>

Return (or set) the name of the current confidence map. If a map is to be 
returned every effort is made to guarantee that it is suitable for use.

  $cpm = $Cal->CPM;
  $Cal->CPM($newCPM);

=cut


sub CPM {

    my $self = shift;

    if (@_) {
        return $self->CPMname(shift);
    };

    my $ok = $self->CPMindex->verify($self->CPMname,$self->thing,0);

    # happy ending

    return $self->CPMname if $ok;

    croak ("Override confidence map is not suitable! Giving up") 
        if $self->CPMnoupdate;

    if (defined $ok) {
        my $cpm = $self->CPMindex->choosebydt('ORACTIME',$self->thing,0);
        if (! defined $cpm) {
            croak "No suitable confidence map was found in index file";
        }

        # Store the good value

        $self->CPMname($cpm);

    } else {

        # All fall down....

        croak("Error in determining confidence map - giving up");
    }
}

=item B<photom>

Return (or set) the name of the current photometry source.  No guarantee of
suitability is made currently -- we just hope the user knows what he/she/it
is doing (hope springs eternal).

    $photom = $Cal->photom;
    $Cal->photom($newphotom);

=cut

sub photom {
    my $self = shift;

    if (@_) {
        return $self->photomname(shift);
    } else {
        return $self->photomname;
    }
}

=item B<astrom>

Return (or set) the name of the current astrometry source.  No guarantee of
suitability is made currently -- we just hope the user knows what he/she/it
is doing (hope springs eternal).

    $astrom = $Cal->astrom;
    $Cal->astrom($newastrom);

=cut

sub astrom {
    my $self = shift;

    if (@_) {
        return $self->astromname(shift);
    } else {
        return $self->astromname;
    }
}

=item B<flat>

Return (or set) the name of the current flat.

  $flat = $Cal->flat;

Stolen from the base class soley in order to get rid of the boring warning
messages every time you need to change flats because you are doing a different
chip...

=cut


sub flat {
    my $self = shift;
    if (@_) {

        # if we are setting, accept the value and return

        return $self->flatname(shift);
    };

    my $ok = $self->flatindex->verify($self->flatname,$self->thing,0);

    # happy ending - frame is ok

    if ($ok) {return $self->flatname};

    croak("Override flat is not suitable! Giving up") if $self->flatnoupdate;

    # not so good

    if (defined $ok) {
        my $flat = $self->flatindex->choosebydt('ORACTIME',$self->thing,0);
        croak "No suitable flat was found in index file" unless defined $flat;
        $self->flatname($flat);
    } else {
        croak("Error in flat calibration checking - giving up");
    };
};


=item B<dark>

Return (or set) the name of the current dark - checks suitability on return.

Stolen from the base class soley in order to get rid of the boring warning
messages every time you need to change darks because you are doing a different
chip...

=cut

sub dark {
    my $self = shift;
    if (@_) {

        # if we are setting, accept the value and return

        return $self->darkname(shift);
    };

    my $ok = $self->darkindex->verify($self->darkname,$self->thing,0);

    # happy ending - frame is ok

    if ($ok) {return $self->darkname};
    croak("Override dark is not suitable! Giving up") if $self->darknoupdate;

    # not so good

    if (defined $ok) {
        my $dark = $self->darkindex->choosebydt('ORACTIME',$self->thing,0);
        croak "No suitable dark calibration was found in index file"
            unless defined $dark;
        $self->darkname($dark);
    } else {
        croak("Error in dark calibration checking - giving up");
    };
};

=item B<readnoise>

Determine the readnoise to be used for the current observation.
This method returns a number rather than a particular file even
though it uses an index file.

Croaks if it was not possible to determine a valid readnoise.
(usually indicating that ARRAY_TESTS have not been reduced).

  $readnoise = $Cal->readnoise;

The index file is queried every time (usually not a problem since there
are only a limited number of array tests per night and the index
is cached in memory) unless the noupdate flag is true.

If the noupdate flag is set there is no verification that the readnoise
meets the specified rules (this is because the command-line override
uses a value rather than a file).

The index file must include a column named READNOISE.
Subclassed from Calib.pm to provide a nominal value in the event that no
readnoise index file is defined.

=cut

sub readnoise {
  my $self = shift;
  my $nominal = 25.0;

  # Handle arguments
  return $self->readnoisecache(shift) if @_;

  # If noupdate is in effect we should return the cached value
  # unless it is not defined. This effectively allows the command-line
  # value to be used to override without verifying its suitability
  if ($self->readnoisenoupdate) {
    my $cache = $self->readnoisecache;
    return $cache if defined $cache;
  }

  # Now we are looking for a value from the index file
  my $noisefile = $self->readnoiseindex->choosebydt('ORACTIME',$self->thing);
  if (! defined $noisefile) {
      orac_warn "No suitable readnoise value found in index file\n";
      return $nominal;
  }

  # This gives us the filename, we now need to get the actual value
  # of the readnoise.
  my $noiseref = $self->readnoiseindex->indexentry( $noisefile );
  if (exists $noiseref->{READNOISE}) {
    return $noiseref->{READNOISE};
  } else {
    orac_warn "Unable to obtain READNOISE from index file entry $noisefile\n";
    return $nominal;
  }

}

=back

=head1 REVISION

$Id$

=head1 AUTHORS

Jim Lewis (jrl@ast.cam.ac.uk)

=head1 COPYRIGHT

Copyright (C) 2002-2004 Cambridge Astronomy Survey Unit
All Rights Reserved.

=cut


1;
