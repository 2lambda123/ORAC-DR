
#+
#  Name:
#     oracdr_iris2

#  Purpose:
#     Initialise ORAC-DR environment for use with IRIS2

#  Language:
#     C-shell script

#  Invocation:
#     source ${ORAC_DIR}/etc/oracdr_iris2.csh

#  Description:
#     This script initialises the environment variables and command
#     aliases required to run the ORAC-DR pipeline with IRIS2 data.
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
#        If no value is set, "/irisdata" is assumed.
#     $ORAC_CAL_ROOT = Environment Variable (Given)
#        Root location of the calibration files. $ORAC_DATA_CAL
#        is derived from this variable by adding the appropriate
#        value of $ORAC_INSTRUMENT. In this case $ORAC_DATA_CAL
#        is set to $ORAC_CAL_ROOT/iris2. If ORAC_CAL_ROOT is not
#        defined it defaults to "/iris_sw/oracdr_cal".


#  Examples:
#     oracdr_iris2
#        Will set the variables assuming the current UT date.
#     oracdr_iris2 19991015
#        Use UT data 19991015

#  Notes:
#     - The environment variables $ORAC_RECIPE_DIR and $ORAC_PRIMITIVE_DIR
#     are unset by this routine if they have been set.
#     - The data directories are assumed to be in directories "raw"
#     (for input) and "reduced" (for output) from root
#     $ORAC_DATA_ROOT/iris2_data/UT
#     - $ORAC_DATA_OUT and $ORAC_DATA_IN will have to be
#     set manually if the UKIRT directory structure is not in use.
#     - aliases are set in the oracdr_start.csh script sourced by
#     this routine.

#  Authors:
#     Frossie Economou (frossie@jach.hawaii.edu)
#     Tim Jenness (t.jenness@jach.hawaii.edu)
#     {enter_new_authors_here}

#  History:
#     $Log$
#     Revision 1.1  2001/07/03 03:11:32  timj
#     template for IRIS2
#
#     Revision 1.3  2000/08/05 07:38:29  frossie
#     ORAC style
#
#     Revision 1.2  2000/02/03 03:43:38  timj
#     Correct doc typo
#
#     Revision 1.1  2000/02/03 02:50:45  timj
#     Starlink startup scripts
#
#     02 Jun 1999 (frossie)
#        Original Version

#  Revision:
#     $Id$

#  Copyright:
#     Copyright (C) 1998-2000 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.

#-



# orac things
if !($?ORAC_DATA_ROOT) then
    setenv ORAC_DATA_ROOT /irisdata
endif

if !($?ORAC_CAL_ROOT) then
    # Need to choose somewhere sensible although
    # this is a fallback as we normally expect
    # ORAC_CAL_ROOT to be set in the same way as ORAC_DIR
    setenv ORAC_CAL_ROOT /iris_sw/oracdr_cal
endif

if ($?ORAC_RECIPE_DIR) then
    echo "Warning: resetting ORAC_RECIPE_DIR"
    unsetenv ORAC_RECIPE_DIR
endif

if ($?ORAC_PRIMITIVE_DIR) then
    echo "Warning: resetting ORAC_PRIMITIVE_DIR"
    unsetenv ORAC_PRIMITIVE_DIR
endif


if ($1 != "") then
    set oracut = $1
else
    set oracut = `date -u +%Y%m%d`
endif

set oracdr_args = "-ut $oracut"

# Data directories for IRIS2 only have a 2 digit year

set oracut_cut = `echo $oracut | cut -c 3-8`

setenv ORAC_INSTRUMENT IRIS2
setenv ORAC_DATA_IN $ORAC_DATA_ROOT/raw/iris2/$oracut_cut/
setenv ORAC_DATA_OUT  $ORAC_DATA_ROOT/reduced/iris2/$oracut_cut/
setenv ORAC_DATA_CAL $ORAC_CAL_ROOT/iris2

# screen things
setenv ORAC_PERSON oracdr_iris2
setenv ORAC_LOOP wait
setenv ORAC_SUN  ???

# Source general alias file and print welcome screen
source $ORAC_DIR/etc/oracdr_start.csh

# Tidy up
unset oracut_cut
unset oracut
unset oracdr_args
