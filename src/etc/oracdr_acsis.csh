#+
#  Name:
#     oracdr_acsis

#  Purpose:
#     Initialise ORAC-DR environment for use with ACSIS

#  Language:
#     C-shell script

#  Invocation:
#     source ${ORAC_DIR}/etc/oracdr_acsis.csh

#  Description:
#     This script initialises the environment variables and command
#     aliases required to run the ORAC-DR pipeline with ACSIS data.
#     An optional argument is the UT date. This is used to configure
#     the input and output data directories but assumes an ACSIS
#     style directory configuration.

#  ADAM Parameters:
#     UT = INTEGER (Given)
#        UT date of interest. This should be in YYYYMMDD format.
#        It is used to set the location of the input and output
#        data directories. Assumes that the data are located in
#        a directory structure similar to that used at JCMT for ACSIS.
#        Also sets an appropriate alias for ORAC-DR itself.
#        If no value is specified, the current UT is used.
#     $ORAC_DATA_ROOT = Environment Variable (Given)
#        Root location of the data input and output directories.
#        If no value is set, current directory is assumed unless
#        the script is running at the JAC, in which case the root
#        directory points to the location of the ACSIS archive.
#     $ORAC_CAL_ROOT = Environment Variable (Given)
#        Root location of the calibration files. $ORAC_DATA_CAL
#        is derived from this variable by adding the appropriate
#        value of $ORAC_INSTRUMENT. In this case $ORAC_DATA_CAL
#        is set to $ORAC_CAL_ROOT/acsis. If ORAC_CAL_ROOT is not
#        defined it defaults to "/jcmt_sw/oracdr_cal".

#  Examples:
#     oracdr_acsis
#        Will set the variables assuming the current UT date.
#     oracdr_acsis 20040919
#        Use UT data 20040919

#  Notes:
#     - The environment variables $ORAC_RECIPE_DIR and $ORAC_PRIMITIVE_DIR
#     are unset by this routine if they have been set.
#     - $ORAC_DATA_OUT is set to the current working directory by default.
#     - $ORAC_DATA_OUT and $ORAC_DATA_IN may have to be
#     may have to be set manually after this command is issued.
#     - aliases are set in the oracdr_start.csh script sourced by
#     this routine.
 
 
#  Authors:
#     Tim Jenness (t.jenness@jach.hawaii.edu)
#     Frossie Economou (frossie@jach.hawaii.edu)
#     Brad Cavanagh (b.cavanagh@jach.hawaii.edu)
#     {enter_new_authors_here}
 
#  History:
#     $Log$
#     Revision 1.1  2004/06/07 20:40:39  bradc
#     initial addition for ACSIS
#
#
 
#  Revision:
#     $Id$
 
#  Copyright:
#     Copyright (C) 1998-2004 Particle Physics and Astronomy Research
#     Council. All Rights Reserved.
 
#-
 
# Calibration root
if !($?ORAC_CAL_ROOT) then
    setenv ORAC_CAL_ROOT /jcmt_sw/oracdr_cal
endif
 
# Recipe dir
if ($?ORAC_RECIPE_DIR) then
    echo "Warning: resetting ORAC_RECIPE_DIR"
    unsetenv ORAC_RECIPE_DIR
endif
 
# primitive dir
if ($?ORAC_PRIMITIVE_DIR) then
    echo "Warning: resetting ORAC_PRIMITIVE_DIR"
    unsetenv ORAC_PRIMITIVE_DIR
endif
 
#  Read the input UT date
if ($1 != "") then
    set oracut = $1
else
    set oracut = `date -u +%Y%m%d`
endif
 
set oracdr_args = "-ut $oracut"
 
# Instrument
setenv ORAC_INSTRUMENT ACSIS

# Cal Directories
setenv ORAC_DATA_CAL $ORAC_CAL_ROOT/acsis
 
# Data directories
setenv ORAC_DATA_ROOT /jcmtdata
setenv ORAC_DATA_IN $ORAC_DATA_ROOT/raw/acsis/$oracut/
setenv ORAC_DATA_OUT $ORAC_DATA_ROOT/reduced/acsis/$oracut/
 
# screen things
setenv ORAC_PERSON jleech
setenv ORAC_LOOP 'flag'
setenv ORAC_SUN  ???
 
# Source general alias file and print welcome screen
source $ORAC_DIR/etc/oracdr_start.csh
 
# Tidy up
unset oracut
unset oracdr_args
unset orachost
