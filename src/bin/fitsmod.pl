#!/usr/bin/perl

=head1 NAME

fitsmod.pl -- Demonstration script showing how to edit headers for ORAC-DR.

=head1 SYNOPSIS

   fitsmod.pl FITS_file [FITS_file2 ...]

=head1 DESCRIPTION

This Perl script is an example of how to modify headers of a FITS file
generated by UFTI in situ.  In normal circumstances this should not be
necessary.  Sometimes things go awry during your observing at 14000
feet.  The most common is an error in the observation `exec' file,
such as not starting a new group or not setting the correct recipe for
a dark frame.  In such cases the headers of some frames will need
editing so that the ORAC-DR pipeline can reduce the data correctly.

It is intended that you copy and adapt this script to your requirements.
The main steps are as follows.

=over 4

=item 1.

Open the FITS file.  You must have write access.

=item 2.

Read the relevant headers, one or more of OBSTYPE, OBSNUM, GRPNUM,
GRPMEM, and RECIPE.  The code and comments explain these further.
Note that three are related by the formula GRPMEM = OBSNUM - GRPNUM + 1.

=item 3.

Perform the calculations or assign substitute values.

=item 4.

Update the headers to contain the modified values.

=item 5.

Close the file.

=back

=head1 ARGUMENTS

A space-separated list of UFTI FITS files to modify.  The usual shell
file wildcards may be included.

=head1 NOTES

If you are squeamish and prefer not to edit the raw data frames, you
can run the ORAC-DR pipeline

      oracdr -from 1 QUICK_LOOK -nodisplay

to convert the FITS files to NDFs for the night's observations.  Then
use the FITSMOD task in KAPPA to edit the headers.  See SUN/232 for
examples.

=head1 REQUIREMENTS

The Astro::FITS::CFITSIO Perl module, available from http://www.cpan.org/.
This may already be installed at your site.

=head1 AUTHOR

Malcolm J. Currie (JAC)

=cut

# We need the Astro::FITS::CFITSIO library to manipulate the FITS header.
   use Astro::FITS::CFITSIO qw( :longnames );
   use Astro::FITS::CFITSIO qw( :constants );

# Declare variables.
   my ( $obstype, $grpnum, $grpmem, $obsnum, $recipe );
   my ( $typscomment, $numcomment, $memcomment, $obscomment, $reccomment );

# Initialise the inherited status to OK.
   my $status = 0;

# Process each FITS file listed on the command line.
    foreach my $file ( @ARGV ) {
       print "Editing headers in file: $file\n";

# Open the FITS file.
       my $fitsfile = CFITSIO::open_file( $file, CFITSIO::READWRITE(), $status );
       if ( $status ) {
          die "Can't open file: $!";
       }

# Obtain the headers pertinent to ORAC.
# =====================================

# Obtain the OBSTYPE string value and associated comment.   OBSTYPE
# is the observation type, and will normally be "DARK", "OBJECT", or
# "SKY".
       $fitsfile->read_key( TSTRING, "OBSTYPE", $obstype, $typcomment, $status );

# Obtain the OBSNUM integer value and associated comment.  OBSNUM is
# the frame number of the observation, starting from 1 on each night.
       $fitsfile->read_key( TINT, "OBSNUM", $obsnum, $obscomment, $status );

# Obtain the GRPNUM integer value and associated comment.  GRPNUM
# specifies the number of observation (group of frames), and should be
# given by the frame number (OBSNUM) of its first member.
       $fitsfile->read_key( TINT, "GRPNUM", $grpnum, $numcomment, $status );

# Obtain the GRPMEM integer value and associated comment.  GRPMEM
# specifies the sequence number within the group, counting from 1.
       $fitsfile->read_key( TINT, "GRPMEM", $grpmem, $memcomment, $status );

# Obtain the RECIPE name and assoicated comment.
       $fitsfile->read_key( TSTRING, "RECIPE", $recipe, $reccomment, $status );

# Make changes to values here.
# ============================

# Here do some arithmetic or set replacement values as required by your
# data.   This might be placing frames in the correct groups.

# In the example below, the GRPMEM after frame 31 is in error.  The frames
# supplied are part of observations in groups of five.

# Specify the group sequence number and the group number.
       $grpmem = ( $obsnum - 31 ) % 5;
       if ( $grpmem == 0 ) {
          $grpmem = 5;
       }

# Note this equation.  This defines the inter-relationships between
# the integer counters.  Rearrange as needed for your editing.
       $grpnum = $obsnum - $grpmem + 1;

# We might do special things to dark frames.  Here the previous formula
# for the new GRPMEM expected only object frames.
       if ( $obstype eq "DARK" ) {

# Set the group number to OBSNUM.
          $fitsfile->update_key( TINT, "GRPNUM", $obsnum, $numcomment, $status );
          $grpmem = $obsnum - $grpnum + 1;
          $fitsfile->update_key( TINT, "GRPMEM", $grpmem, $memcomment, $status );

# Set the RECIPE value.  It is REDUCE_DARK for dark frames.
          $fitsfile->update_key( TSTRING, "RECIPE", "REDUCE_DARK",
                                 $reccomment, $status );

# A dark in this example implies that a wrong frame was selected.
          print "Warning obsnum $obsnum is a dark.  Exiting\n";
          exit;

       } else {

# Replace the revised group number and group sequence number.
          $fitsfile->update_key( TINT, "GRPNUM", $grpnum, $numcomment, $status );
          $fitsfile->update_key( TINT, "GRPMEM", $grpmem, $memcomment, $status );

# Set the RECIPE value.  BRIGHT_POINT_SOURCE_APHOT expects a five-point
# jitter, hence the modulo 5 earlier.
          $fitsfile->update_key( TSTRING, "RECIPE", "BRIGHT_POINT_SOURCE_APHOT",
                                 $reccomment, $status );
       }

# Close the FITS file.
       $fitsfile->close_file( $status );

    }
