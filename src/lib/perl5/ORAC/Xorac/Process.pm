package ORAC::Xorac::Process;

# ---------------------------------------------------------------------------

#+ 
#  Name:
#    ORAC::Xorac::Process

#  Purposes:
#    Process launcher routines called from the Xoracdr

#  Language:
#    Perl module

#  Description:
#    This module contains the process launching routines for Xoracdr

#  Authors:
#    Alasdair Allan (aa@astro.ex.ac.uk)
#     {enter_new_authors_here}

#  Revision:
#     $Id$

#  Copyright:
#     Copyright (C) 1998-2001 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.

#-

# ---------------------------------------------------------------------------

use strict;                  # smack! Don't do it again!
use Carp;                    # Transfer the blame to someone else
  
# P O D  D O C U M E N T A T I O N ------------------------------------------

=head1 NAME

ORAC::Xorac:: - process launcher routines called from Xoracdr

=head1 SYNOPSIS

  use ORAC::Xorac::Process
  
  xorac_start_process( \%options, $inst_select );

=head1 DESCRIPTION

This module contains the process launching routines for Xoracdr

=head1 REVISION

$Id$

=head1 AUTHORS

Alasdair Allan (aa@astro.ex.ac.uk)

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research Council.
All Rights Reserved.

=cut

# L O A D  M O D U L E S --------------------------------------------------- 

#
#  ORAC modules
#
use ORAC::Basic;        # orac_exit_normally
use ORAC::Event;        # Tk hash table
use ORAC::General;
use ORAC::Error qw/:try/;

#
# Routines for export
#
require Exporter;
use vars qw/$VERSION @EXPORT @ISA /;

@ISA = qw/Exporter/;
@EXPORT = qw/ xorac_start_process  /;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# S U B R O U T I N E S -----------------------------------------------------

=head1 SUBROUTINES

The following subroutines are available:

=over 4

=cut

# xorac_start_process() ---------------------------------------------------

=item B<xorac_start_process>

=cut

sub xorac_start_process {

  croak 'Usage: xorac_start_process( \%options, $inst_select, \$CURRENT_RECIPE, \$Override_Recipe, \@obs )'
    unless scalar(@_) == 5;

  # Read the argument list
  my ( $options, $inst_select, $CURRENT_RECIPE, $Override_Recipe, $obs ) = @_;

  use ORAC::Print;     # Printing messages or errors
  use ORAC::Core;      # Core pipeline routines
  use ORAC::Constants; # ORAC__OK et al
  use ORAC::Xorac;
  use ORAC::Inst::Defn qw/ orac_determine_inst_classes /;
  use Tk;

  ####### C H E C K  E N V I R O N M E N T  V A R I A B L E S ################

  # Simply exit if the environment variable is not set, this should not occur
  unless (exists $ENV{"ORAC_INSTRUMENT"}) 
  {
     orac_err(" No instrument specified in \$ORAC_INSTRUMENT.\n");
     return;
  }
  
  my $instrument = uc($ENV{"ORAC_INSTRUMENT"});

  # Get class definitions for this instrument
  my ($frameclass, $groupclass, $calclass, $instclass) =
                         orac_determine_inst_classes( $instrument );
  return unless defined $frameclass;
  
  # Create a new instrument object
  my $InstObj = new $instclass;
 
  ############# O P T I O N  H A N D L I N G #################################
 
  # Turn on -w supprt
  if ( ${$options}{"warn"} ) {  
    $^W=1;
    if (${$options}{"verbose"}) {
       eval "use diagnostics;";
    }
  }
 
  ########## O R A C - D R  C O N F I G U R A T I O N ########################

  unless (exists $ENV{"ORAC_DIR"}) 
  {
     orac_err(" ORAC_DIR environment variable not defined. Aborting.");
     return;
  }

  ######## C H A N G E   T O   O U T P U T   D I R E C TO R Y  ###############

  if (exists $ENV{"ORAC_DATA_OUT"}) {

     # change to output  dir
     chdir($ENV{"ORAC_DATA_OUT"}) ||
       do { 
         orac_err(" Could not change directory to ORAC_DATA_OUT: $!");
         return;
       };

  } 
  else 
  {
     orac_err(" ORAC_DATA_OUT environment variable not set. Aborting\n");
     return;
  }
  
  ############### C H E C K  I N P U T  D I R E C T O R Y ####################

  if (exists $ENV{"ORAC_DATA_IN"}) 
  {
     unless (-d $ENV{"ORAC_DATA_IN"}) 
     {
     orac_err(" ORAC_DATA_IN directory ($ENV{ORAC_DATA_IN}) does not exist.\n");
     return;
     }
  
  } 
  else 
  {
     orac_err(" ORAC_DATA_IN environment variable not set. Aborting\n");
     return;
  }

  ######### O R A C  P R I N T  C O N F I G U R A T I O N #####################

  # declare variables
  my ($log_options, $TL, $win_str);

  $log_options = $log_options . "f" if( ${$options}{"log_file"} == 1);
  $log_options = $log_options . "s" if( ${$options}{"log_screen"} == 1);
  $log_options = $log_options . "x" if( ${$options}{"log_xwin"} == 1);
    
  # create a new toplevel window for the log frames 
  if ( $log_options =~ /x/ )
  {
      $TL = ORAC::Event->query("Tk")->Toplevel();
      ORAC::Event->register("TL"=>$TL);
      $win_str = "TL";   
      $TL->title("Xoracdr Log Window");
      $TL->iconname("Log Window");
      $TL->geometry("+160+60");
  }

  # start print system, pass $TL
  my ( $orac_prt, $msg_prt, $msgerr_prt, $ORAC_MESSAGE, 
       $PRIMITIVE_LIST, $CURRENT_PRIMITIVE );

  try 
  {
     ( $orac_prt, $msg_prt, $msgerr_prt, $ORAC_MESSAGE, 
       $PRIMITIVE_LIST, $CURRENT_PRIMITIVE ) =
        orac_print_configuration(${$options}{"debug"},
	                         ${$options}{"showcurrent"}, 
	                         $log_options, $win_str, $CURRENT_RECIPE );
  }
  catch ORAC::Error::FatalError with 
  {
      my $Error = shift;
      $Error->throw;
  }
  catch ORAC::Error::UserAbort with
  {
     my $Error = shift;
     $Error->throw;
  };
  $$CURRENT_RECIPE = "Starting pipeline";
  
  ######################## M E S S A G E  S Y S T E M S #######################

  # pre-launch message system
  try {
     orac_message_launch( ${$options}{"nomsgtmp"}, ${$options}{"verbose"} );
  }
  catch ORAC::Error::FatalError with 
  {
     my $Error = shift;
     $Error->throw;
  }
  catch ORAC::Error::UserAbort with
  {
     my $Error = shift;
     $Error->throw;
  };
    
  ######################## A L G.   E N G I N E S #############################

  # start algorithim engines
  my $Mon;
  
  try {
     $Mon = orac_start_algorithm_engines( ${$options}{"noeng"}, $InstObj );
  }
  catch ORAC::Error::FatalError with 
  {
     my $Error = shift;
     $Error->throw;     
  }
  catch ORAC::Error::UserAbort with
  {
     my $Error = shift;
     $Error->throw;
  };

  ####################### B E E P I N G #######################################

  # Beeping
  if (${$options}{"beep"}) {
    $orac_prt->errbeep(1);
    # Beep is for orac_exit_normally so must set global in the correct class
    $ORAC::Basic::Beep = 1;
  }

  ######################## I N I T  D I S P L A Y #############################

  # start the display
  my $Display = orac_start_display( ${$options}{"nodisplay"} );
  
  ######################## C A L I B R A T I O N ##############################

  # Calibration frame overrides
  my $Cal = orac_calib_override( ${$options}{"calib"}, $calclass );
  
  ################## P R O C E S S  A R G U M E N T  L I S T ##################

  # Generate list of observation numbers to be processed
  # This is related to looping scheme
  my $loop =  
    orac_process_argument_list( ${$options}{"from"}, ${$options}{"to"},
                                 ${$options}{"skip"}, ${$options}{"list"},
                                 $frameclass, $obs );
 
  ##################### L O O P I N G  S C H E M E ############################

  # Decide on a looping scheme
  $loop = "orac_loop_" . ${$options}{"loop"} if defined ${$options}{"loop"};

  ########################## D A T A   L O O P ################################
 
  # Over ride recipe 
  my $Use_Recipe;
  if ( defined ${$options}{"override"} == 1 ) {
     $Use_Recipe = $$Override_Recipe;
  } else {
     undef $Use_Recipe; 
  }
      
  # Call the main data processing loop
  try {
     orac_main_data_loop( ${$options}{"batch"}, ${$options}{"ut"}, 
                          ${$options}{"resume"}, ${$options}{"skip"},
	   	          ${$options}{"debug"}, $loop, $frameclass, $groupclass,
		          $instrument, $Mon, $Cal, $obs, $Display, $orac_prt,
		          $ORAC_MESSAGE, $CURRENT_RECIPE, $PRIMITIVE_LIST,
			  $CURRENT_PRIMITIVE, $Use_Recipe );
     orac_print ("Pipeline processing complete\n", "green");
     return;
  }
  catch ORAC::Error::FatalError with 
  {
     my $Error = shift;

     print "Fatal Error in Xorac::Process Main Loop\n";
     print "Error was: $Error\n";
    
     return;
  }
  catch ORAC::Error::UserAbort with
  {
     my $Error = shift;
     
     print "User Abort in Xorac::Process Main Loop\n";
     return;
  }

 
}


# ----------------------------------------------------------------------------

1;
