
#+
#  Name:
#     oracdr_ingrid

#  Purpose:
#     Initialises ORAC-DR environment for use with INGRID.

#  Language:
#     sh shell script

#  Invocation:
#     source ${ORAC_DIR}/etc/oracdr_ingrid.sh

#  Description:
#     This script initialises the environment variables and command
#     aliases required to run the ORAC-DR pipeline with INGRID data.
#     An optional argument is the UT date.  This is used to configure
#     the input and output data directories but assumes a UKIRT
#     style directory configuration.

#  ADAM Parameters:
#     UT = INTEGER (Given)
#        UT date of interest.  This should be in YYYYMMDD format.
#        It is used to set the location of the input and output
#        data directories.  Assumes that the data are located in 
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
#        is set to $ORAC_CAL_ROOT/INGRID.  If ORAC_CAL_ROOT is not
#        defined it defaults to "/jac_sw/oracdr_cal".


#  Examples:
#     oracdr_ingrid
#        Will set the variables assuming the current UT date.
#     oracdr_ingrid 20030201
#        Use UT data 

#  Notes:
#     - The environment variables $ORAC_RECIPE_DIR and $ORAC_PRIMITIVE_DIR
#     are unset by this routine if they have been set.
#     - The data directories are assumed to be in directories "raw"
#     (for input) and "reduced" (for output) from root
#     $ORAC_DATA_ROOT/ufti_data/UT
#     - $ORAC_DATA_OUT and $ORAC_DATA_IN will have to be
#     set manually if the UKIRT directory structure is not in use.
#     - aliases are set in the oracdr_start.sh script sourced by
#     this routine.

#  Authors:
#     Malcolm j. Currie (mjc@star.rl.ac.uk)
#     Frossie Economou (frossie@jach.hawaii.edu)
#     Tim Jenness (t.jenness@jach.hawaii.edu)
#     {enter_new_authors_here}

#  History:
#     2002 Feb 20 (MJC):
#        Original version.

#  Revision:
#     $Id$

#  Copyright:
#     Copyright (C) 1998-2003 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.

#-

# orac things
if test -z "$ORAC_DATA_ROOT"; then
    export ORAC_DATA_ROOT=/ukirtdata
fi

if test -z "$ORAC_CAL_ROOT"; then
    export ORAC_CAL_ROOT=/jac_sw/oracdr_cal
fi

if ! test -z "$ORAC_RECIPE_DIR"; then
    echo "Warning: resetting ORAC_RECIPE_DIR"
    unset ORAC_RECIPE_DIR
fi

if ! test -z "$ORAC_PRIMITIVE_DIR"; then
    echo "Warning: resetting ORAC_PRIMITIVE_DIR"
    unset ORAC_PRIMITIVE_DIR
fi


if test ! -z "$1"; then
    oracut=$1
else
    oracut=`\date -u +%Y%m%d`
fi

export oracdr_args="-ut $oracut"

export ORAC_INSTRUMENT=INGRID
export ORAC_DATA_IN=$ORAC_DATA_ROOT/raw/ingrid/$oracut/
export ORAC_DATA_OUT=$ORAC_DATA_ROOT/reduced/ingrid/$oracut/
export ORAC_DATA_CAL=$ORAC_CAL_ROOT/ingrid

# screen things
export ORAC_PERSON=mjc
export ORAC_LOOP=flag
export ORAC_SUN=232

# Source general alias file and print welcome screen
. $ORAC_DIR/etc/oracdr_start.sh

# Tidy up
unset oracut
unset oracdr_args
