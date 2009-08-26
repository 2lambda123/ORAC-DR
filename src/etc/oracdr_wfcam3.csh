
#+
#  Name:
#     oracdr_wfcam3

#  Purpose:
#     Initialise ORAC-DR environment for use with the third WFCAM
#     chip.

#  Language:
#     C-shell script

#  Invocation:
#     source ${ORAC_DIR}/etc/oracdr_wfcam3.csh

#  Description:
#     This script initialises the environment variables and command
#     aliases required to run the ORAC-DR pipeline with WFCAM data.
#     An optional argument is the UT date. This is used to configure
#     the input and output data directories but assumes a UKIRT
#     style directory configuration.

#  ADAM Parameters:
#     UT = INTEGER (Given)
#        UT date of interest. This should be in YYYYMMDD format.
#        It is used to set the location of the input and output
#        data directories. Assumes that the data are located in
#        a directory structure similar to that used at UKIRT.
#        Also sets an appropriate alias for ORAC-DR itself.
#        If no value is specified, the current UT is used.
#     $ORAC_DATA_ROOT = Environment Variable (Given)
#        Root location of the data input and output directories.
#        If no value is set, "/ukirtdata" is assumed.
#     $ORAC_CAL_ROOT = Environment Variable (Given)
#        Root location of the calibration files. $ORAC_DATA_CAL
#        is derived from this variable by adding the appropriate
#        value of $ORAC_INSTRUMENT. In this case $ORAC_DATA_CAL
#        is set to $ORAC_CAL_ROOT/wfcam. If ORAC_CAL_ROOT is not
#        defined it defaults to "$ORAC_DIR/../cal".


#  Examples:
#     oracdr_wfcam3
#        Will set the variables assuming the current UT date.
#     oracdr_wfcam3 19991015
#        Use UT data 19991015

#  Notes:
#     - The environment variables $ORAC_RECIPE_DIR and $ORAC_PRIMITIVE_DIR
#     are unset by this routine if they have been set.
#     - The data directories are assumed to be in directories "raw"
#     (for input) and "reduced" (for output) from root
#     $ORAC_DATA_ROOT/wfcam3/UT
#     - $ORAC_DATA_OUT and $ORAC_DATA_IN will have to be
#     set manually if the UKIRT directory structure is not in use.
#     - aliases are set in the oracdr_start.csh script sourced by
#     this routine.

#  Authors:
#     Frossie Economou (frossie@jach.hawaii.edu)
#     Tim Jenness (t.jenness@jach.hawaii.edu)
#     Brad Cavanagh (b.cavanagh@jach.hawaii.edu)
#     {enter_new_authors_here}

#  Copyright:
#     Copyright (C) 1998-2002 Particle Physics and Astronomy Research
#     Council. 2009 Science and Technology Facilities Council. All
#     Rights Reserved.

#-

setenv ORAC_INSTRUMENT WFCAM3

# Set the UT date.
set oracut=`${ORAC_DIR}/etc/oracdr_set_ut.csh $1`

# Find Perl.
set starperl=`${ORAC_DIR}/etc/oracdr_locateperl.sh`

# Run initialization.
set orac_env_setup=`$starperl ${ORAC_DIR}/etc/setup_oracdr_env.pl csh $oracut`
if ( $? != 0 ) then
  echo "**** ERROR IN setup_oracdr_env.pl ****"
  exit 255
endif
eval $orac_env_setup

set oracdr_args = "-ut $oracut -grptrans"

# Create WFCAM output data directory if necessary.
source $ORAC_DIR/etc/create_wfcam_dir.csh

# Set additional WFCAM environment variables.
source $ORAC_DIR/etc/oracdr_wfcam_env.csh

# Source general alias file and print welcome screen
source $ORAC_DIR/etc/oracdr_start.csh

# Tidy up
unset oracut
unset starperl
unset oracdr_args

