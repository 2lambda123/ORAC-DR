# Must be an ARC observation for CGS4
# Note that this isnt necessarily true for Michelle
# Leave this in for UIST for now.
ORAC_OBSERVATION_MODE eq 'ARC'

# Do not force a match on readout mode (PH,THK)
# but it's nice to have it in the index file
ORAC_DETECTOR_READ_TYPE

# Do NOT requre a match on filter

# CNFINDEX must match, unconditionally (PH,THK)
#ORAC_CONFIGURATION_INDEX eq $Hdr{"ORAC_CONFIGURATION_INDEX"}

# Basic optical parameters must match
ORAC_SLIT_NAME eq $Hdr{"ORAC_SLIT_NAME"}

# I suppose it should match readout areas (historic)
ORAC_X_LOWER_BOUND == $Hdr{"ORAC_X_LOWER_BOUND"}
ORAC_Y_LOWER_BOUND == $Hdr{"ORAC_Y_LOWER_BOUND"}
ORAC_X_UPPER_BOUND == $Hdr{"ORAC_X_UPPER_BOUND"}
ORAC_Y_UPPER_BOUND == $Hdr{"ORAC_Y_UPPER_BOUND"}

# Ensure ORACTIME goes into the rules file
ORACTIME
