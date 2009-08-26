#!perl

use strict;
use File::Spec;

# Check environment variables.
if( ! defined( $ENV{'ORAC_DIR'} ) ) {
  die "ORAC_DIR environment variable not set!";
}
if( ! defined( $ENV{'ORAC_CAL_ROOT'} ) ) {
  $ENV{'ORAC_CAL_ROOT'} = File::Spec->catfile( $ENV{'ORAC_DIR'}, File::Spec->updir, "cal" );
}
if( ! defined( $ENV{'ORAC_PERL5LIB'} ) ) {
  $ENV{'ORAC_PERL5LIB'} = File::Spec->catfile( $ENV{'ORAC_DIR'}, "lib", "perl5" );
}

# Handle arguments.
my $shell = uc( $ARGV[0] );
my $ut = $ARGV[1];

if( ! defined( $shell ) ) {
  $shell = "csh";
}
if( ! defined( $ut ) ) {
  $ut = `date -u +\%Y\%m\%d`;
}

my $inst = uc( $ENV{'ORAC_INSTRUMENT'} );

# Special case for WFCAM.
if( $inst =~ /^WFCAM/ ) {
  $inst = "WFCAM";
}

# Default ORAC_DATA_ROOT directories.
my %dataroot = ( 'ACSIS'  => "/jcmtdata",
                 'CGS4'   => "/ukirtdata",
                 'IRCAM'  => "/ukirtdata",
                 'IRCAM2' => "/ukirtdata",
                 'MICHELLE' => "/ukirtdata",
                 'WFCAM'  => "/ukirtdata",
               );

my $dataroot = ( defined( $ENV{'ORAC_DATA_ROOT'} ) ? $ENV{'ORAC_DATA_ROOT'} : $dataroot{$inst} );

# Environment variable hash.
my %envs = ( 'ACSIS'  => { ORAC_DATA_CAL => File::Spec->catfile( $ENV{'ORAC_CAL_ROOT'}, "acsis" ),
                           ORAC_DATA_ROOT => $dataroot,
                           ORAC_DATA_IN => File::Spec->catfile( $dataroot, "raw", "acsis", "spectra", $ut ),
                           ORAC_DATA_OUT => File::Spec->catfile( $dataroot, "reduced", "acsis", "spectra", $ut ),
                           ORAC_LOOP => 'flag',
                           ORAC_PERSON => 'bradc',
                           ORAC_SUN => 'xxx',
                         },
             'CGS4'   => { ORAC_DATA_CAL => File::Spec->catfile( $ENV{'ORAC_CAL_ROOT'}, "cgs4" ),
                           ORAC_DATA_ROOT => $dataroot,
                           ORAC_DATA_IN => File::Spec->catfile( $dataroot, "raw", "cgs4", $ut ),
                           ORAC_DATA_OUT => File::Spec->catfile( $dataroot, "reduced", "cgs4", $ut ),
                           ORAC_PERSON => 'bradc',
                           ORAC_LOOP => 'flag',
                           ORAC_SUN => '230',
                         },
             'IRCAM'  => { ORAC_DATA_CAL => File::Spec->catfile( $ENV{'ORAC_CAL_ROOT'}, "ircam" ),
                           ORAC_DATA_ROOT => $dataroot,
                           ORAC_DATA_IN => File::Spec->catfile( $dataroot, "ircam_data", $ut, "rodir" ),
                           ORAC_DATA_OUT => File::Spec->catfile( $dataroot, "ircam_data", $ut, "rodir" ),
                           ORAC_PERSON => 'mjc',
                           ORAC_LOOP => 'wait',
                           ORAC_SUN => '232',
                         },
             'IRCAM2' => { ORAC_DATA_CAL => File::Spec->catfile( $ENV{'ORAC_CAL_ROOT'}, "ircam" ),
                           ORAC_DATA_ROOT => $dataroot,
                           ORAC_DATA_IN => File::Spec->catfile( $dataroot, "raw", "ircam", $ut ),
                           ORAC_DATA_OUT => File::Spec->catfile( $dataroot, "reduced", "ircam", $ut ),
                           ORAC_PERSON => 'mjc',
                           ORAC_LOOP => 'flag',
                           ORAC_SUN => '232',
                         },
             'MICHELLE' => { ORAC_DATA_CAL => File::Spec->catfile( $ENV{'ORAC_CAL_ROOT'}, "michelle" ),
                             ORAC_DATA_ROOT => $dataroot,
                             ORAC_DATA_IN => File::Spec->catfile( $dataroot, "raw", "michelle", $ut ),
                             ORAC_DATA_OUT => File::Spec->catfile( $dataroot, "reduced", "michelle", $ut ),
                             ORAC_PERSON => 'mjc',
                             ORAC_LOOP => 'flag',
                             ORAC_SUN => '232,236',
                           },
             'WFCAM'  => { ORAC_DATA_CAL => File::Spec->catfile( $ENV{'ORAC_CAL_ROOT'}, "wfcam" ),
                           ORAC_DATA_ROOT => $dataroot,
                           ORAC_DATA_IN => File::Spec->catfile( $dataroot, "raw", lc( $ENV{'ORAC_INSTRUMENT'} ), $ut ),
                           ORAC_DATA_OUT => File::Spec->catfile( $dataroot, "reduced", lc( $ENV{'ORAC_INSTRUMENT'} ), $ut ),
                           ORAC_PERSON => 'bradc',
                           ORAC_LOOP => 'flag',
                           ORAC_SUN => '',
                           HDS_MAP => 0,
                         },
           );

# List of instrument-agnostic variables to send back.
my @orac_envs = qw/ ORAC_CAL_ROOT ORAC_PERL5LIB /;

# Print out the environment variable settings.
foreach my $env ( keys %{$envs{$inst}} ) {
  my $value = $envs{$inst}->{$env};
  if( $shell eq 'CSH' ) {
    print "setenv $env '$value' ; ";
  } elsif( $shell eq 'BASH' ) {
    print "export $env='$value' ; ";
  }
}

# ...and the instrument-agnostic ones too.
foreach my $oracenv ( @orac_envs ) {
  if( $shell eq 'CSH' ) {
    print "setenv $oracenv '$ENV{$oracenv}' ; ";
  } elsif( $shell eq 'BASH' ) {
    print "export $oracenv='$ENV{$oracenv}' ; ";
  }
}

