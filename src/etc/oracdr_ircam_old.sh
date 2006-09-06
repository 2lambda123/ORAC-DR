
#+
#  Name:
#     oracdr_ircam

#  Purpose:
#     Initialise ORAC-DR environment for use with IRCAM

#  Language:
#     sh shell script

#  Invocation:
#     source ${ORAC_DIR}/etc/oracdr_ircam.sh

#  Description:
#     This script initialises the environment variables and command
#     aliases required to run the ORAC-DR pipeline with IRCAM data.
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
#        is set to $ORAC_CAL_ROOT/ufti. If ORAC_CAL_ROOT is not
#        defined it defaults to "/ukirt_sw/oracdr_cal".


#  Examples:
#     oracdr_ircam
#        Will set the variables assuming the current UT date.
#     oracdr_ircam 19991015
#        Use UT data 19991015

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
#     Frossie Economou (frossie@jach.hawaii.edu)
#     Tim Jenness (t.jenness@jach.hawaii.edu)
#     {enter_new_authors_here}

#  History:
#     $Log$
#     Revision 1.1  2006/09/06 02:29:55  bradc
#     initial addition
#
#     Revision 1.1  2000/08/05 07:38:21  frossie
#     ORAC style
#
#     Revision 1.3  2000/02/09 21:33:57  timj
#     Fix $ut to $oracut
#
#     Revision 1.2  2000/02/03 03:43:38  timj
#     Correct doc typo
#
#     Revision 1.1  2000/02/03 02:50:44  timj
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
if !("$ORAC_DATA_ROOT" != ""); then
    export ORAC_DATA_ROOT=/ukirtdata
fi

if !("$ORAC_CAL_ROOT" != ""); then
    export ORAC_CAL_ROOT=/ukirt_sw/oracdr_cal
fi

if ("$ORAC_RECIPE_DIR" != ""); then
    echo "Warning: resetting ORAC_RECIPE_DIR"
    unsetenv ORAC_RECIPE_DIR
fi

if ("$ORAC_PRIMITIVE_DIR" != ""); then
    echo "Warning: resetting ORAC_PRIMITIVE_DIR"
    unsetenv ORAC_PRIMITIVE_DIR
fi


if ($1 != ""); then
    set oracut = $1
    set oracsut = `echo $oracut |cut -c3-8`
else
    set oracut = `date -u +%Y%m%d`
    set oracsut = `date -u +%y%m%d`
fi

set oracdr_args = "-ut $oracsut"


export ORAC_INSTRUMENT=IRCAM
export ORAC_DATA_IN=$ORAC_DATA_ROOT/ircam_data/$oracut/rodir
export ORAC_DATA_OUT=$ORAC_DATA_ROOT/ircam_data/$oracut/rodir
export ORAC_DATA_CAL=$ORAC_CAL_ROOT/ircam


# screen things
export ORAC_PERSON=mjc
export ORAC_LOOP=wait
export ORAC_SUN=232


# Source general alias file and print welcome screen
source $ORAC_DIR/etc/oracdr_start.csh

# Tidy up
unset oracut
unset oracdr_args
unset oracsut
