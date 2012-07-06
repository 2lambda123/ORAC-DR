
#+
#  Name:
#     oracdr_swfcam1

#  Purpose:
#     Initialise ORAC-DR environment for use with the short-wave
#     SCUBA-2 arrays

#  Language:
#     sh shell script

#  Invocation:
#     source ${ORAC_DIR}/etc/oracdr_scuba2_850.sh

#  Description:
#     This script initialises the environment variables and command
#     aliases required to run the ORAC-DR pipeline with SCUBA-2 data.
#     An optional argument is the UT date. This is used to configure
#     the input and output data directories but assumes a JAC
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
#        If no value is set, "/jcmtdata" is assumed.
#     $ORAC_CAL_ROOT = Environment Variable (Given)
#        Root location of the calibration files. $ORAC_DATA_CAL
#        is derived from this variable by adding the appropriate
#        value of $ORAC_INSTRUMENT. In this case $ORAC_DATA_CAL
#        is set to $ORAC_CAL_ROOT/scuba2. If ORAC_CAL_ROOT is not
#        defined it defaults to "/jcmt_sw/oracdr_cal".


#  Examples:
#     oracdr_scuba2_850
#        Will set the variables assuming the current UT date.
#     oracdr_scuba2_850 19991015
#        Use UT data 19991015

#  Notes:
#     - The environment variables $ORAC_RECIPE_DIR and $ORAC_PRIMITIVE_DIR
#     are unset by this routine if they have been set.
#     - The data directories are assumed to be in directories "raw"
#     (for input) and "reduced" (for output) from root
#     $ORAC_DATA_ROOT/scuba2/sx/UT
#     - $ORAC_DATA_OUT and $ORAC_DATA_IN will have to be
#     set manually if the JAC directory structure is not in use.
#     - aliases are set in the oracdr_start.sh script sourced by
#     this routine.

#  Authors:
#     Frossie Economou (frossie@jach.hawaii.edu)
#     Tim Jenness (t.jenness@jach.hawaii.edu)
#     Brad Cavanagh (b.cavanagh@jach.hawaii.edu)
#     {enter_new_authors_here}

#  History:
#     $Log$
#     Revision 1.2  2006/09/07 00:35:25  bradc
#     fix for proper bash scripting
#
#     Revision 1.1  2006/09/06 02:30:05  bradc
#     initial addition
#
#     Revision 1.1  2005/02/26 08:15:04  timj
#     Initial commit of scuba2 init script
#
#     Revision 1.3  2004/11/12 01:22:02  phirst
#      setenv RTD_REMOTE_DIR and HDS_MAP
#
#     Revision 1.2  2004/11/10 02:31:49  bradc
#     ORAC_DATA_CAL is in swfcam, not wfcam now
#
#     Revision 1.1  2004/09/14 21:17:37  bradc
#     initial addition for SWFCAM
#
#     Revision 1.2  2004/05/05 11:38:57  jrl
#     Modified to add ORAC_DATA_CASU definition and a small tidy
#
#     Revision 1.1  2003/06/30 09:43:05  jrl
#     initial entry into CVS
#
#     Revision 1.1  2003/01/22 11:54:49  jrl
#     Initial Entry
#
#
#     21 Jan 2003 (jrl)
#        Original Version based on oracdr_wfcam.sh

#  Copyright:
#     Copyright (C) 1998-2005 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.

#-

export ORAC_INSTRUMENT=SCUBA2_450

# Source general alias file and print welcome screen
. $ORAC_DIR/etc/oracdr_start.sh

# Set stripchart alias
if test -z $ORAC_DATA_CAL; then
  alias xstripchart="${STARLINK_DIR}/bin/starperl ${STARLINK_DIR}/xstripchart -cfg=$ORAC_DATA_CAL/jcmt_long.ini &"
fi
