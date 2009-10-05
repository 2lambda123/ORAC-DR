#+
#  Name:
#     oracdr_classiccam

#  Purpose:
#     Initialises ORAC-DR environment for use with ClassicCam

#  Language:
#     sh shell script

#  Invocation:
#     source ${ORAC_DIR}/etc/oracdr_classiccam.sh

#  Description:
#     This script initialises the environment variables and command
#     aliases required to run the ORAC-DR pipeline with ClassicCam data.
#     An optional argument is the UT date.  This is used to configure
#     the input and output data directories but assumes a UKIRT
#     style directory configuration.

#  ADAM Parameters:
#     UT = INTEGER (Given)
#        The UT date of interest.  This should be in YYYYMMDD format.
#        It is used to set the location of the input and output data
#        directories.  This assumes that the data are located in a
#        directory structure similar to that used at UKIRT.  The UT date
#        also sets an appropriate alias for ORAC-DR itself.  If no value
#        is specified, the current UT date is used.
#     $ORAC_DATA_ROOT = Environment Variable (Given & Returned)
#        The root location of the data input and output directories.
#        If no value is set, $ORAC_DATA_ROOT is set to "/ukirtdata".
#     $ORAC_CAL_ROOT = Environment Variable (Given & Returned)
#        The root location of the calibration files.  $ORAC_DATA_CAL is
#        derived from this variable by adding the appropriate value of
#        $ORAC_INSTRUMENT.  In this case $ORAC_DATA_CAL is set to
#        $ORAC_CAL_ROOT/classiccam.  If ORAC_CAL_ROOT is not defined
#        defined it defaults to "/jac_sw/oracdr_cal".

#  Examples:
#     oracdr_classiccam
#        Will set the variables assuming the current UT date.
#     oracdr_classiccam 19991015
#        Use UT data 19991015

#  Notes:
#     - The environment variables ORAC_RECIPE_DIR and ORAC_PRIMITIVE_DIR
#     are unset by this routine if they have been set.
#     - The data directories are assumed to be:
#     $ORAC_DATA_ROOT/raw/classiccam/<UT> for the "raw" data, and
#     $ORAC_DATA_ROOT/reduced/classiccam/<UT> for the "reduced" data.
#     - $ORAC_DATA_OUT and $ORAC_DATA_IN will have to be
#     set manually if the UKIRT directory structure is not in use.
#     - aliases are set in the oracdr_start.sh script sourced by
#     this routine.

#  Authors:
#     Frossie Economou (frossie@jach.hawaii.edu)
#     Tim Jenness (t.jenness@jach.hawaii.edu)
#     MJC: Malcolm J. Currie (mjc@jach.hawaii.edu)
#     {enter_new_authors_here}

#  History:
#     2003 July 17 (MJC):
#        Original version based upon ISAAC equivalent.

#  Copyright:
#     Copyright (C) 1998-2003 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.

#-

export ORAC_INSTRUMENT=CLASSICCAM

# Source general alias file and print welcome screen
. $ORAC_DIR/etc/oracdr_start.sh
