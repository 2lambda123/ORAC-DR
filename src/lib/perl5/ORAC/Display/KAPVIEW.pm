package ORAC::Display::KAPVIEW;

=head1 NAME

ORAC::Display::KAPVIEW - ORACDR interface to Kapview (Kappa)

=head1 SYNOPSIS

  use ORAC::Display::KAPVIEW;
  $disp = new ORAC::Display::KAPVIEW;

  $disp->image($file, { XAUTOSCALE => 1});

=head1 DESCRIPTION

ORAC interface to Kappa Kapview. Provides methods for displaying images
and spectrum with Kapview.

Available options are:

IMAGE - display image using DISPLAY
GRAPH - display graph using LINPLOT
SIGMA - display scatter plot with a Y-range of +/- N sigma.
DATAMODEL - Display data (as points) with a model overlaid
HISTOGRAM - Histogram of values in data array
VECTOR - Display image + vectors

=cut

use 5.004;
use Carp;
use strict;

use ORAC::Msg::ADAM::Task;
use ORAC::Msg::ADAM::Control;

use File::Copy;
use Cwd;

use NDF;  # To read image bounds

use ORAC::Print;
use ORAC::Constants qw/:status/;        #  Constants
use ORAC::General;                      # Max and min

use base qw/ ORAC::Display::Base /;     # Base class

use vars qw/$VERSION $DEBUG $AGI_USER $AGI_NODE $KAPPA13/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

$DEBUG = 0;

# The KAPPA13 variable is true if we are using Kappa v0.13
# and false otherwise. Dynamically check which version
# by looking in the KAPPA_DIR directory

if (-e "$ENV{KAPPA_DIR}/style.def") {
  $KAPPA13 = 1;
} else {
  $KAPPA13 = 0;
}


=head1 PUBLIC METHODS

=head2 Constructor

=over 4

=item B<new>

Object constructor. The constructor starts up a new version of kapview,
starts a GWM window and displays the startup logo.

The program aborts if there is an error launching kapview.

The message system must be running so that Kapview can be configured.
(AMS is started if needed)

=cut


sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Create a new instance from the base class
  my $disp = $class->SUPER::new(Obj => undef,    # Messaging object
				AMS => undef,    # Adam message system
				Kappa => undef,  # Kappa_mon object
				Ndfpack=> undef, # Ndfpack_mon object
				Polpack => undef, # Polpack mon object
				Regions => {},
			       );

  # Start message system (should just return if already started)
  my $status = ORAC__OK;
  $disp->{AMS} = new ORAC::Msg::ADAM::Control;
  $status = $disp->{AMS}->init;

  # Configure the AGI environment variables
  # Should tidy this up when we finish
  BEGIN { # A kluge - for some reason kapview does not pick up the
          # correct environment if I leave out the BEGIN block
          # dont understand since the environment is passed to the forked
          # process...
    $ENV{'AGI_USER'} = "/tmp";
    $ENV{'AGI_NODE'} = "orac_kapview$$";
  }

  # Store these values so that I know what file to remove 
  # independent of whether some other module has redefined them
  $AGI_USER = $ENV{AGI_USER};
  $AGI_NODE = $ENV{AGI_NODE};

  # Split the launching and configuration into separate subroutines
  if ($status == ORAC__OK) {
    $disp->launch;
    $status = $disp->configure;
  }

  # There has been an error launching kapview. We have no choice
  # but to die at this point since as soon as the current object
  # goes out of scope the kapview monolith will be killed.
  # The assumption is that if the kapview monolith had problems there
  # is no point keeping it around.
  # A related problem is that once we have tried to launch kapview 
  # (and managed to start a monolith the first time) the messaging
  # system never gets informed that the monolith died so next time
  # you try it the system thinks kapview is running and so doesn't launch
  # a new one. When you then try to contact anything you get a segmentation
  # fault because of the screwed message system.
  if ($status != ORAC__OK) {
    die "Error launching Kapview. It is unlikely that this can be fixed by retrying from within ORACDR. Please rerun either with the display switched off or with a different display device selected.";
  }
  
  return $disp;
}

=back

=head2 Accessor Methods

=over 4

=item B<kappa>

Messaging object associated with the kappa_mon monolith.
This is used by some of the modes in order to determine
display related values (eg statistics to determine plotting
ranges for SIGMA, dimension compression with COMPAVE).

A kappa messaging object is created if the object is undefined.

Note also that the HISTOGRAM task is present in the kappa monolith
rather than in the KAPVIEW monolith.

=cut

sub kappa {
  my $self = shift;
  if (@_) { $self->{Kappa} = shift; }

  # Start kappa if needed
  unless (defined $self->{Kappa}) {
    orac_print ("Creating Kappa_mon object.............\n",'cyan') if $DEBUG;

    # Note that a MONOLITH name is supplied as an option.
    # This is so that if a path to the monolith exists and it
    # is an A-task [note that we dont specify task type - if a
    # kappa monolith is already running on this path as an I-task
    # then parameter retrieval will fail. It is possible that in the
    # future the objects will be stored so that if a monolith is started
    # by the same process in a different piece of code a copy of the
    # task object will be returned rather than creating a new one.)
    # Currently this is still a bit of a kluge and requires some knowledge
    # of the way that the kappa monolith used by the recipes was started.
    $self->{Kappa} = new ORAC::Msg::ADAM::Task("kappa_mon_$$", 
					       "$ENV{KAPPA_DIR}/kappa_mon",
					       { MONOLITH => 'kappa_mon' }
					      ); 
  }

  return $self->{Kappa};
}

=item B<ndfpack>

Messaging object associated with the ndfpack_mon monolith.
This is used by some of the modes in order to reshape
date arrays (eg in SIGMA mode - reshape is run to convert
to 1-d)

A NdfPack messaging object is created if the object is undefined.

=cut

sub ndfpack {
  my $self = shift;
  if (@_) { $self->{Ndfpack} = shift; }

  # Start ndfpack if needed
  unless (defined $self->{Ndfpack}) {
    orac_print ("Creating Ndfpack_mon object.............\n",'cyan') if $DEBUG;

    # Note that a MONOLITH name is supplied as an option.
    # This is so that if a path to the monolith exists and it
    # is an A-task [note that we dont specify task type - if a
    # kappa monolith is already running on this path as an I-task
    # then parameter retrieval will fail. It is possible that in the
    # future the objects will be stored so that if a monolith is started
    # by the same process in a different piece of code a copy of the
    # task object will be returned rather than creating a new one.)
    # Currently this is still a bit of a kluge and requires some knowledge
    # of the way that the kappa monolith used by the recipes was started.
    $self->{Ndfpack} = new ORAC::Msg::ADAM::Task("ndfpack_mon_$$", 
					       "$ENV{KAPPA_DIR}/ndfpack_mon",
					       { MONOLITH => 'ndfpack_mon' }
					      ); 
  }

  return $self->{Ndfpack};
}


=item B<polpack>

Messaging object associated with the polpack_mon monolith.
This is used by the VECTOR mode to plot vectors from catalogues.

Note that this is technically not part of the KAPVIEW system.
It is here for convenience since in all cases POLPLOT is better
than VECPLOT for vector plotting.

A Polpack messaging object is created if the object is undefined.

Returns undef if polpack_mon is not available.

=cut

sub polpack {
  my $self = shift;
  if (@_) { $self->{Polpack} = shift; }

  # Start polpack if needed
  unless (defined $self->{Polpack}) {
    if (-e "$ENV{POLPACK_DIR}/polpack_mon") {

      orac_print ("Creating Polpack_mon object.............\n",'cyan') 
	if $DEBUG;

      # Note that a MONOLITH name is supplied as an option.
      # This is so that if a path to the monolith exists and it
      # is an A-task [note that we dont specify task type - if a
      # kappa monolith is already running on this path as an I-task
      # then parameter retrieval will fail. It is possible that in the
      # future the objects will be stored so that if a monolith is started
      # by the same process in a different piece of code a copy of the
      # task object will be returned rather than creating a new one.)
      # Currently this is still a bit of a kluge and requires some knowledge
      # of the way that the kappa monolith used by the recipes was started.
      $self->{Polpack} = new ORAC::Msg::ADAM::Task("polpack_mon_$$", 
						   "$ENV{POLPACK_DIR}/polpack_mon",
						   { MONOLITH => 'polpack_mon' }
						  );
      # Wait for it to start if necessary
      unless ($self->{Polpack}->contactw) {
	return undef;
      }	
    }
  }
  return $self->{Polpack};
}


=item B<regions>

A hash containing the mapping of region name (number) to
AGI picture label.

Returns hash reference in scalar context, full hash in array context.
Contents can be modified by directly using the hash reference
(in order to modify specific entries) or completely rewritten by
supplying a hash as argument.

  $hashref = $self->regions;
  %hash = $self->regions;
  $self->regions(%hash);
  $self->regions->{Key} = "value";

=cut

sub regions {
  my $self = shift;

  if (@_) {
    %{ $self->{Regions}} = @_;
  }

  if (wantarray()) {
    return %{$self->{Regions}};
  } else {
    return $self->{Regions};
  }
}


=item B<obj>

Messaging object associated with the Kapview display object.

=cut

sub obj {
  my $self = shift;
  if (@_) { $self->{Obj} = shift; }
  return $self->{Obj};
}


=back

=head2 General Methods

=over 4

=item B<newdev>

Given 'win', calculates a new device name that should be unique for
each 'win'.

 $dev = $Display->newdev($win);

=cut

sub newdev {
  my $self = shift;
  my $win = shift;
  
  my $dev = "xwindows;" . "$win" ."_oracdrxwin";

  return $dev;
}


=item B<create_dev>

Start the GWM window associated with the supplied window.
In general this is used by the startup configuration.
The lookup table is configured by this routine (so that
this routine really does start the GWM window).

Currently the GWM window itself is not started directly
by this routine (since KAPVIEW will automatically open
the specified device if one is not running).

The only reason to use this routine to actually START a window
is that it will give us some control over the colour allocation
and allow us to set the window name.

ORAC status is returned.

  $status = $Display->create_dev($win);

Currently, the method dies if the device can not be successfully
created.

=cut

sub create_dev {
  my $self = shift;
  my $window = shift;

  # Get the device - this would enter an infinite loop if 
  # window_dev failed to return an existing device name 
  # - since window_dev calls create_dev
  my $device = $self->window_dev($window);

  # If I want to start GWM myself I have to do the following
#  my $gwm = new Proc::Simple;
#  $gwm->start("gwm -colours 128 -gwmname $device -name \'ORACDR:P4 (${device}xwin)\'");
  # Pause so that GWM window can be contacted immediately
  # sleep 2;

  # The problem here is that if 'gwmname' matches an exisiting gwm
  # window then the gwm command crashes. This should be okay if  I
  # can hide the error message. Otherwise I need to check to see whether
  # the window is there beforehand (eg with the ps command)


  # Now every time we open a new device we need to configure
  # lookup table.
  # in general this means that the monolith must have started
  # and contact made
  # Load the colour table

  my $args = "mapping=linear coltab=external lut=$ENV{KAPPA_DIR}/bgyrw_lut";
  my $status = $self->obj->obeyw("lutable","$args device=$device");
  if ($status != ORAC__OK) {
    orac_err("Error configuring default LUT\n");
    die "Error launching display device. It is unlikely that this can be fixed by retrying from within ORACDR. Aborting...";
#    return $status;
  }

  # try a paldef
  $status = $self->obj->obeyw("paldef","device=$device");
  if ($status != ORAC__OK) {
    orac_err("Error setting default pallette\n");
    die "Error launching display device. It is unlikely that this can be fixed by retrying from within ORACDR. Aborting...";
#    return $status;
  }

  # If this all works we should now configure the display regions
  $status = $self->config_regions($window);
  if ($status != ORAC__OK) {
    orac_err "Error configuring regions\n";
    die "Error launching display device. It is unlikely that this can be fixed by retrying from within ORACDR. Aborting...";
  }


  return ORAC__OK;

}


=item B<launch>

This method starts the kapview monolith and stores the associated
Task object.

=cut

sub launch {
  my $self = shift;

  # Start kapview
  orac_print ("Starting KAPVIEW........................\n",'cyan') if $DEBUG;
  my $display = new ORAC::Msg::ADAM::Task("kapview_mon_$$", "$ENV{KAPPA_DIR}/kapview_mon"); 

  # Store the object
  $self->obj($display);

}


=item B<configure>

Load a startup image. This tests the system to make sure that images
can be displayed and that the colour map is loaded.

Returns ORAC status.

=cut

sub configure {
  my $self = shift;

  my $status;

  # Now try to contact the kapview monolith (this will cause trouble
  # if AMS is not running.

  my $contact =$self->obj->contactw;         # ensure contact is made
  unless ($contact) {
    orac_err("Unable to contact Display (kapview) before timeout");
    return $status;
  }

  # open the GWM window
  # and configure the lookup table
#  $status = $self->create_dev('default');
#  return $status unless $status == ORAC__OK; 

  my $startup = "$ENV{ORAC_DIR}/images/orac_start";

  # Set the device for port_0 for our default display
  # This will automatically launch the device and configure the
  # display regions
  my $device = $self->window_dev('default');

  # Replace $ with \$ for eval during obeyw()
  my $data = $startup;
  $data =~ s/\$/\\\$/g;  
 
  # Configure region 0
  $device = $self->select_region( WINDOW=>'default',REGION=>0);
  unless (defined $device) {
    orac_err("Error configuring display. Possible invalid region designation\n");
    return ORAC__ERROR;
  }

  # Ask Kapview to display
  $status = $self->obj->resetpars;
  $status = $self->obj->obeyw("display", "in=$data mode=sc device=$device noaxes accept");
  if ($status != ORAC__OK) {
    orac_err("Error displaying startup image\n");
    orac_err("Trying to execute: display in=$data\n");
  }
 
  return $status;
  
}


=item B<config_regions>

This method configures the display regions so that they can be
selected later by select_region.

  $status = $self->config_regions($window);

A window name must be supplied.

The regions are defined as follows:

  0 - full screen
  1 - top left
  2 - top right
  3 - bottom left
  4 - bottom right
  5 - left
  6 - right
  7 - top
  8 - bottom
  17:32 - position in 4x4 grid (starting top left)

The picture labels are stored in the regions() array.

=cut

sub config_regions {
  my $self = shift;
  return ORAC__ERROR unless @_;

  my $window = shift;

  my $device = $self->window_dev($window);

  my ($status, %piclabels);

  # First, we can create the regions that are setup
  # one-by-one (ie not on a grid)
  # Store the definitions in a hash, the key is the region label

  my %regions = (
		 0 => "cc [1,1]",
		 5 => "cl [0.5,1.0]", 
		 6 => "cr [0.5,1.0]",
		 7 => "tl [1.0,0.5]", 
		 8 => "bl [1.0,0.5]",
		);

  # Loop over the regions, running picdef and piclabel
  foreach my $region (keys %regions) {
    my $string = $regions{$region};

    orac_print("Configuring AGI region $region with $string\n",'cyan') if $DEBUG;

    # Configure with PICDEF
    $status = $self->obj->obeyw("picdef","device=$device nocurrent nooutline $string");

    last unless $status == ORAC__OK;

    # Label it - name is ORACa_REGION
    my $label = "ORAC0_$region";

    $status = $self->obj->obeyw("piclabel","device=$device label=$label");
    last unless $status == ORAC__OK;

    # Store the label
    $piclabels{$region} = $label;

  }

  # Now we can create the 2x2  and 4x4 grids
  foreach my $n (2,4) {
    my $nx = $n;
    my $ny = $n;
    my $ntot = $nx * $ny;

    my $prefix = "ORAC${n}_";

    orac_print("Configuring AGI database with $nx x $ny grid\n",'cyan') if $DEBUG;
    $status = $self->obj->obeyw("picdef","device=$device nocurrent mode=a prefix=$prefix xpic=$nx ypic=$ny nooutline");

    next unless $status == ORAC__OK;

    # Successfully created the regions
    # now need to store the labels in %piclabels remembering that
    # the numbering starts at bottom-left for kappa but top-left
    # for ORAC-DR

    # The region number must be relative to some offset
    # For 2x2 the numbering should start at 1, for 4x4 numbering
    # should start at 17
    my $offset = ($n == 2 ? 0 : 16);

    for my $i (1..$ntot) {
      orac_print("Looping $i..." ,'cyan') if $DEBUG;
      # To map from bottom-left-corner to top-left you need
      # ( N = number starting from top left)
      
      # KappaN = N - Ntotal - Nx + 
      #                        2 * Nx * (Ny +1 - int( (N + Nx - 1) / Nx ))

      my $kappan = $i - $ntot - $nx + ( 2 * $nx * ($ny + 1 - int(($i + $nx - 1)/ $nx)));

      # Calculate the actual region number
      my $region = $i + $offset;

      # Store the label
      $piclabels{$region} = "ORAC${n}_$kappan";

      orac_print("Region $region : $piclabels{$region}\n",'cyan')
	if $DEBUG;

    }

  }

  # Store the labels (probably do not want to do this afresh for each window)
  $self->regions(%piclabels);

  # Status warning
  if ($status != ORAC__OK) {
    orac_err "Error occurred whilst configuring display device $device\n";
  }

  return $status;
}


=item B<select_region>

Selects the requested region as the current region in the display
system by using a supplied hash.

  $device = $Display->select_region(%options);

Returns undef without action if the REGION keyword is not available
(since have no idea where to put it) or if REGION is not in the
allowed range.  Otherwise the name of the device containing the selected
region is returned. undef is returned if no arguments are supplied.

If the window name is not supplied (WINDOW) then 'default' is assumed.

=cut

sub select_region {
  my $self = shift;

  return undef unless @_;

  my %options = @_;

  my $region = undef;

  if (exists $options{REGION}) {
    $region = $options{REGION};
    orac_print("Region is $region\n",'cyan') if $DEBUG;
  } else {
    return undef;
  }

  # Port must be an integer
  if ($region !~ /^\d+$/) {
    orac_err "Supplied region specification ($region) not a positive integer\n";
    return undef;
  }

  # Find the Window name
  my $window = 'default';
  if (exists $options{WINDOW}) {
    $window = $options{WINDOW};
  }
  # and convert it into a device id
  my $device = $self->window_dev($window);

  # Now need to select the requested region

  # Check that the requested region is defined
  unless (exists $self->regions->{$region} && defined $self->regions->{$region}) {
    orac_err "Supplied region specification ($region) does not correspond to a defined region on the device\n";
    return undef;
  }

  # The mapping of region number to picture name is stored in
  # the region() array
  
  my $picname = $self->regions->{$region};


  # Now run PICSEL to select the picture
  my $status = $self->obj->obeyw("picsel","$picname device=$device");

  # Check status
  if ($status != ORAC__OK) {
    orac_err("Error selecting picture $picname (Region $region)\n");
    return undef;
  }

  return $device;

}


=item B<select_section>

This method converts a file name and options hash into
a filename with an attached NDF section.

  $newfile = $Display->select_section($file, \%options, $dimensionality);

An optional 3rd argument can be used to specify the required 
dimensionality. If the number of dimensions in the data file is
greater than that requested, sections in higher dimensions
are set to 1 by compressing the undesired dimension
(with the assumption that KAPPA will discard axes
with 1 pixel). The desired dimension is specified with the CUT
option. For example, a graph can be displayed from a 2-D image
by displaying a cut in the X direction (averaging over the Ys).

If the number of dimensions in the data file
is fewer than that requested, a warning message is printed
but we continue in the hope that KAPPA will work something out....

The return value is the original filename with the
NDF section attached.

Relevant keywords in options hash:

  CUT  - Specify the significant dimension[s] (X,Y,3,4,5)
         Should be a comma-separated list specifying 
         dimensionality - number of entries should equal the
         requested dimensionality. For a graph only 1 value
         is required since a graph is 1-D
  XMIN/XMAX - X pixel max and min values
  YMIN/YMAX - Y pixel max and min values
  XAUTOSCALE - Use autoscaling for X?
  YAUTOSCALE - Use autoscaling for Y?

If Xautoscale and Yautoscale are true, no section command is appended.
If the XAUTOSCALE/YAUTOSCALE/nAUTOSCALE keywords can not be found they are
assumed to be true. If CUT is not specified  the first slice is
selected (eg a NDF section of N,1,1,1)

For data arrays with N>2, the leading letter is dropped and replaced
by the dimension number. eg:

  3MIN/3MAX - pixel range of the 3rd dimension
  4AUTOSCALE - autoscale the 4th dimension?

For NDFs the maximum dimensionality is 7.

The bounds of the input file are compared to the supplied bounds.
If any of the requested bounds are exceeded, the maximum value
will be used instead. 

Returns undef on error.
The unmodified file name is returned if no options hash can be found.

Returns the following:

  No CUT requested + auto-scaling:
    returns the original filename
  No CUT requested + some dimension ranges specified
    returns the original filename with an NDF section
    Dimensions above the requested dimensionality are set to the
    min value in the section (1 if not specified)
  CUT requested but dimensionality of data matches requested
    dimensionality.
    Just return the file + any relevant section
  CUT + auto-scaling + image too large
    data file is collapsed down to required size keeping the specified
    dimensions and averaging over the rest. A new temporary filename
    is returned
  CUT + some ranges specified + image too large
    NDF section constructed and then the data file is collapsed
    down to the required size. A new temporary file is generated.
  CUT + range + image + one pixel selected
    If the non-cut dimensions have min=max a section is
    sufficient and no averaging required
  
The temporary files themselves are added to a global class
array and removed by the destructor.

Note that this routine does not remove the temporary filename.
This is probably a bug. Should probably create some kind of
object that will have a destructor that removes the file rather
than using a simple file name. (an ORAC::Frame::TmpFile)?

=cut


sub select_section {
  my $self = shift;
  my $file = shift;
  my $options = shift;

  return $file if ref($options) ne 'HASH';

  # Maximum number of allowed dimensions for an NDF
  my $maxdim = 7;  

  # Read the dimensionality (default to 7)
  my $max_requested = $maxdim;
  $max_requested = shift if @_;

  # Take a copy of the options hash
  my %options = %{$options};

  # Define lookup table of prefix (allow up to 7 dimensions)
  my @lookup = ( "X", "Y", 3..$maxdim);
  my @autosc = ();  # Autoscale flags
  my $auto_all = 1; # Flag to keep track of global autoscale
 
  # Read the autoscale flags from the hash
  for my $dim (@lookup) {
    my $autosc = 1;
    my $key = $dim . "AUTOSCALE";
    $autosc = $options{$key} if exists $options{$key};
    push (@autosc, $autosc);

    # Set flag to 0 if any of the autoscale flags are false
    $auto_all = 0 unless $autosc; 
  }

  # Now query the file for its bounds to make sure that the pixel
  # index bounds supplied to not exceed the bounds of the file
  # Could do this by opening the file using NDF or by using the
  # KAPPA ndftrace command. Doing it myself has less overhead
  # (and will use fewer lines!!)

  my $status = &NDF::SAI__OK;
  my ($indf, @lbnd, @ubnd, $ndim);
  ndf_find(&NDF::DAT__ROOT, $file, $indf, $status);
  ndf_bound($indf, 7, @lbnd, @ubnd, $ndim, $status);
  ndf_annul($indf, $status);
  if ($status != &NDF::SAI__OK) {
    err_annul($status);
    orac_err("Error reading bounds from input file: $file");
    return undef;
  }

  # Return the filename if all the autoscale flags are true
  # and the dimensionality does not exceed to maximum requested
  # (Else we will have to generate a section
  return $file if ($auto_all && $ndim <= $max_requested);

  # If we are going to CUT the image two things need to be true
  # 1, the requested CUT dimensions (the significant dimension)
  #    needs to be present in NDIMS (ie no use cutting on dim 3
  #    if only a 2-D image requesting a 1-D slice
  # 2. NDIMS must be greater than requested dims
  # 3. The number of supplied cut dimensions has to equal the 
  #    number of requested dimensions. If too few cuts are specified
  #    (eg a 3-d to 2-d requires 2 cut axes - ie two axes that
  #    are unaffected, the 3rd dimension is averaged), say
  #    only Y is specified for a 3-d to 2-d conversion, the 
  #    X dimension will also be retained. The signifcant (ie retained)
  #    dimensions are counted lowest to highest - X,Y,3,4,5...)

  # If $cutting  is not true then we will simply return a slice of the
  # correct dimensions but assuming 1 dim is most significant
  # and no averaging.

  my $cutting = 0; # Assume no cuts
  my (@cuts); #initialise

  # None of this is significant if the dimensions already match

  if ($ndim > $max_requested) {

    # First create a cut array by splitting on comma
    my @initial_cuts = split(",",$options{CUT});

    # initialise @cuts to an array of 0
    @cuts = map { 0 } @lookup[0..$ndim-1];

    # Strip out dimensions that are not in @lookup[0..$ndim-1]
    # If @cuts contains only 0 then we are not doing a cut
    
    foreach my $cut (@initial_cuts) {
      # Compute $cut with each member of @lookup.
      # if there is a match set cuts[index] to 1 (ie significant)
      # else set it to 0.
      foreach my $index (0..$ndim-1) {
	if ($cut =~ /$lookup[$index]/i) {
	  $cuts[$index] = 1;
	  $cutting = 1;   # We are doing a cut since one matches
	  last;
	}
      }
    }

  }
  # print "CUTS now contains: ",join("::",@cuts) ,"\n";

  # This is an array describing the section for each dimension
  my @sects = ();

  # These arrays containing the actual bounds of each dimension
  # in the section - they are modified in the loop to relfect
  # the sectioning information
  my @min   = @lbnd; # Lower bounds of section for each dim
  my @max   = @ubnd; # upper bounds of section for each dim

  # Loop over all valid dimensions
  for my $dim (1..$ndim) {
    my $index = $dim-1;

    # Check that this dim is mentioned in the lookup table
    if (defined $lookup[$index]) {

      # Check the autoscale flag for this dim
      unless ($autosc[$index]) {

	# Read the bounds from the hash
	my $pre = $lookup[$index];

	# Lower bound is maximum of $lbnd[$dim-1] and 
        # and the minimum of $options{?MIN} and the upper bound
        my $lower = max($lbnd[$index],min($options{"${pre}MIN"},$ubnd[$index]));
        my $upper = min($ubnd[$index],max($options{"${pre}MAX"},$lbnd[$index]));

	# If lower bounds still exceed upper, set lower to upper
        $lower = $upper if $lower > $upper;

        $min[$index]   = $lower;
        $max[$index]   = $upper;

	$sects[$index] = "$lower:$upper";

      } else {
        # An empty section. 
	$sects[$index] = undef;
      }

    }

    # Now we have read the MIN and MAX values from the hash
    # We now need to modify the section a little to cover the
    # case where we are reducing dimensionality without averaging. 
    # In that case we want sections that are higher than the requested
    # dimensionality to be set to the min value (ie 1 pixel
    # wide). If we are reducing dimensiona by averaging the section
    # can stay as is and we will reduce the dims later on by using
    # COMPAVE

    if ($dim > $max_requested && !$cutting) {
      $sects[$index] = $min[$index];
    }

  }  
  
  # Construct the section
  my $section = '('. join(",", @sects) . ')';

  # Set the input file name (no section if $auto_all and $cutting
  my $input;
  if ($auto_all && $cutting) {
    $input = $file;
  } else {
    $input = "$file$section";
  }

  # If we are averaging we need to do that now 
  if ($cutting) {

    # @cuts is an array containing a set of 1 and 0 corresponding
    # to whether a dimension should be kept (1) or averaged over (0)

    # If the number of 1's does not equal the max_requested we have
    # to assume that some of the early dimensions are really significant
    
    # count the 1's [we know that $#cuts matches $ndim-1]
    my $count=0;
    foreach my $i (@cuts) {
      $count++ if $i;
    }

    # If count is too small - correct for it
    # Assume lowest dimension is most significant
    if ($count < $max_requested) {
      foreach (@cuts) {
	if ($_ == 0) {
	  $_ = 1;
	  $count++;
	  last if $count == $max_requested;
	}
      }
    } elsif ($count > $max_requested) {
      # If count is TOO high we need to start from the high end
      # and start setting values to zero - assume highest dimension
      # is least significant.

      for (my $i=$ndim-1; $i>=0; $i--) {

	if ($cuts[$i] = 1) {
	  $cuts[$i] = 0;
	  $count--;
	  last if $count == $max_requested;
	}
      }

    }
    
    # need to construct a string for compave
    # Takes the form of
    #   [ factor1, factor2, factor3...factorN] for Ndims
    # where the factors are the compression factors.
    # for significant dimensions the factor is 1, for all other
    # dimensions the factor is the number of pixels in the dimension
    # (or section) [ie max-min+1]

    # This means that the number of significant dimensions must
    # equal the final required dimensionality. 
    
    # Loop over $ndim constructing COMPRESS key
    my @compress;
    for my $index (0..$ndim-1) {

      # If significant - just put a factor of 1
      if ($cuts[$index]) {
	push(@compress,1);
      } else {
	# To be compressed
	# Factor is npixels
	push(@compress, $max[$index]-$min[$index]+1);
      }
    }

    # If the compression ratios are 1 for all dimensions then
    # we dont actually need to run compave. We can just return
    # the section as stored in $input

    # Check @compress
    my $use_compave = 0;
    foreach (@compress) {
      if ($_ != 1) {
	$use_compave = 1;
	last;
      }
    }

    # If we need to run compave...

    if ($use_compave) {
      my $compress = '[' . join(",",@compress) . ']';

      my $out = "secave$$"; 
      my $compargs = "WLIM=0.1 in=$input out=$out compress=$compress";

      # Run compave
      my $status = $self->kappa->obeyw("compave","$compargs");

      if ($status != ORAC__OK) {
	orac_err("Error running COMPAVE $compargs\n");
	return undef;
      }

      # Now reset $input to be the output of compave
      $input = $out;
    }

  }

  # Return the filename
  return $input;

}

=back

=head1 DISPLAY METHODS

=over 4

=cut

######################## DISPLAY MODES ##############################

=item B<image>

Display an image.
Takes a file name and arguments stored in a hash.
Note that currently it does not take a format argument
and NDF is assumed.

Recognised options:

  XMIN/XMAX - X pixel max and min values
  YMIN/YMAX - Y pixel max and min values
  XAUTOSCALE - Use autoscaling for X?
  YAUTOSCALE - Use autoscaling for Y?
  ZMIN/ZMAX  - Z-range of greyscale (data units)
  ZAUTOSCALE - Autoscale Z?
  COMP       - Component to display (Data (default), Variance or Error)

Default is to autoscale.

ORAC Status is returned.

=cut

sub image {

  my $self = shift;
 
  my $file = shift;

  my $opt;
  my %options = ();
  if (@_) {
    $opt = shift;
    if (ref($opt) eq 'HASH') {
      %options = %{$opt};
    }
  }

  # Configure the display on the basis of REGION specifier
  # ..and return the selected device.
  # Return undef if something went wrong.
  my $device = $self->select_region(%options);

  # If device is now undef we have a problem
  unless (defined $device) {
    orac_err("Error configuring display for IMAGE. Possible invalid region designation\n");
    return ORAC__ERROR;
  }


  # Options handling can not be taken out into a sub since every
  # kapview command has subtly different parameter names,

  # Set the data file name
  $file =~ s/\.sdf$//;  # Strip .sdf

  # Calculate NDF section
  $file = $self->select_section($file,\%options,2);

  # Construct the parameter string for DISPLAY
  my $optstring = " ";

  # Set default scaling
  $optstring .= " mode=scale ";
  # Autoscaling is a special case
  if (exists $options{ZAUTOSCALE}) {
    # Kappa display can autoscale if required
    # Using MODE=SCALE
    
    if ($options{ZAUTOSCALE} == 0) {
      # We are specifying a min and max (check with defined rather
      # than exists since ZMIN=undef is still not helpful)
      $optstring .= " low=$options{ZMIN} " if defined $options{ZMIN};
      $optstring .= " high=$options{ZMAX} " if defined $options{ZMAX};

    }
  }

  # Select component
  if (exists $options{COMP} && defined $options{COMP}) {
    $optstring .= " COMP=$options{COMP}";
  }

  my $status;

  # Get weird errors without the resetpars:
  #!! HDS locator invalid: value=' ', length=15 (possible programming error).
  #!  DAT_CLONE: Error cloning (duplicating) an HDS locator.
  #!  DAT__LOCIN, Locator invalid
  #MODE -- Method to define the scaling limits / 'sc' / > 
 
  # A resetpars also seems to be necessary to instruct kappa to
  # update its current frame for plotting. Without this the new PICDEF
  # regions are not picked up correctly.

  $status = $self->obj->resetpars;
  return $status if $status != ORAC__OK;

  # Do the obeyw
  $status = $self->obj->obeyw("display", "device=$device in=$file axes clear=true $optstring accept");
  if ($status != ORAC__OK) {
    orac_err("Error displaying image\n");
    orac_err("Trying to execute: display device=$device axes clear=true $optstring in=$file\n");
  }

  return $status;

}

=item B<graph>

Display a 1-D plot.

If the data are not 1-D, a section is taken that assures
1-D (eg NDF section= :,1,1,1 for 4D data)

Takes a file name and arguments stored in a hash.
Note that currently it does not take a format argument
and NDF is assumed.

Display keywords:

  XMIN/XMAX  - X-pixel range of graph
  XAUTOSCALE - Autoscale pixel range?
  YMIN/YMAX  - Y-pixel range of graph (in pixels)
  YAUTOSCALE - Autoscale Y-axis
  YMIN/YMAX  - Z-range of graph (in data units)
  YAUTOSCALE - Autoscale Z-axis
  CUT        - Decide which direction is the primary axis
               Can be X,Y,3,4,5 (for higher-dimensional data sets)
               For a 1-D data set (or section), this value is ignored
  COMP       - Component to display (Data (default), Variance or Error)
  

Default is to autoscale. Note that the X/Y cuts are converted
to a 1-D slice before displaying by averaging over the section. 

For example:

   XMIN=5 XMAX=5 YAUTOSCALE=YES 

would display column 5 (ie the whole of Y for X=5).
[CUT is irrelevant since the resulting image section is 1-D]

   XAUTOSCALE=YES YMIN=20 YMAX=30 CUT=X

would display the average of rows 20 and 30 for each X.

Need to add way of controlling line style (eg replace with symbols)

ORAC status is returned.

=cut

sub graph {

  my $self = shift;
 
  my $file = shift;

  my %options = ();
  if (@_) {
    my $opt = shift;
    if (ref($opt) eq 'HASH') {
      %options = %{$opt};
    }
  }

  # Configure the display on the basis of REGION specifier
  # ..and return the selected device.
  # Return undef if something went wrong.
  my $device = $self->select_region(%options);

  # If device is now undef we have a problem
  unless (defined $device) {
    orac_err("Error configuring display for GRAPH. Possible invalid region designation\n");
    return ORAC__ERROR;
  }

  # Set the data file name
  $file =~ s/\.sdf$//;  # Strip .sdf

  # Calculate the NDF section
  $file = $self->select_section($file,\%options,1);

  # A resetpars also seems to be necessary to instruct kappa to
  # update its current frame for plotting. Without this the new PICDEF
  # regions are not picked up correctly.

  my $status = $self->obj->resetpars;
  return $status if $status != ORAC__OK;


  # Should probably set the options
  # If we are autoscaling then we dont need any axis setting
  # default is not to send any axis control information
  my $range;
  if (exists $options{ZAUTOSCALE}) {
    if ($options{ZAUTOSCALE}) {
      if ($KAPPA13) {
	$range = ' ';
      } else {
	$range = "axlim=false";
      }
    } else {
      # Set the Y range
      my $min = 0;
      my $max = 1;
      $min = $options{ZMIN} if defined $options{ZMIN};
      $max = $options{ZMAX} if defined $options{ZMAX};
      if ($KAPPA13) {
	$range = "ytop=$max ybot=$min";
      } else {
	$range = "axlim=true abslim=! ordlim=[$min,$max]";
      }
    }
  }

  # Construct string for linplot options
  my $args = "clear mode=line $range";

  # Select component
  if (exists $options{COMP} && defined $options{COMP}) {
    $args .= " COMP=$options{COMP}";
  }


  # Run linplot
  $status = $self->obj->obeyw("linplot","ndf=$file device=$device $args reset");
  if ($status != ORAC__OK) {
    orac_err("Error displaying graph\n");
    orac_err("Trying to execute: linplot ndf=$file device=$device $args\n");
    return $status;
  }

  return $status;


}


=item B<contour>

Display contours of a 2-D data set.

Recognised options:

  XMIN/XMAX - X pixel max and min values
  YMIN/YMAX - Y pixel max and min values
  XAUTOSCALE - Use autoscaling for X?
  YAUTOSCALE - Use autoscaling for Y?
  ZMIN/ZMAX  - Z-range of greyscale (data units)
  ZAUTOSCALE - Autoscale Z?
  NCONT      - Number of contours
  COMP       - Component to display (Data (default), Variance or Error)

Default is to autoscale.

ORAC status is returned.

=cut

sub contour {

  my $self = shift;
 
  my $file = shift;

  my $opt;
  my %options = ();
  if (@_) {
    $opt = shift;
    if (ref($opt) eq 'HASH') {
      %options = %{$opt};
    }
  }

  # Configure the display on the basis of REGION specifier
  # ..and return the selected device.
  # Return undef if something went wrong.
  my $device = $self->select_region(%options);

  # If device is now undef we have a problem
  unless (defined $device) {
    orac_err("Error configuring display for CONTOUR. Possible invalid region designation\n");
    return ORAC__ERROR;
  }


  # Options handling can not be taken out into a sub since every
  # kapview command has subtly different parameter names,

  # Set the data file name
  $file =~ s/\.sdf$//;  # Strip .sdf

  # Calculate NDF section
  $file = $self->select_section($file,\%options,2);

  # Construct the parameter string for DISPLAY
  my $optstring = " axes clear";

  # Autoscaling is a special case
  my $ncont = $options{NCONT};
  $ncont = 6 if $ncont < 1;

  if (exists $options{ZAUTOSCALE}) {
    # Kappa contour can autoscale if required
    # Using MODE=AU
    
    if ($options{ZAUTOSCALE}) {
      # Set default scaling
      $optstring .= " mode=au ";
    } else {

      # Need to calculate the first contour (ZMIN) +
      # the spacing between contours
      # Use mode=linear
      $optstring .= " mode=lin ";

      if (defined $options{ZMIN}) {
        $optstring .= " firstcnt=$options{ZMIN} ";
      } else {
        $optstring .= " firstcnt=0 ";
      }
 
      # Calculate the increment (stepcnt)
      my $inc = ($options{ZMAX} - $options{ZMIN}) / $ncont;
      $optstring .= " stepcnt=$inc ";
    }
  } else {
    # Set default scaling
    $optstring .= " mode=au ";
  }
  $optstring .= " ncont=$ncont ";  

  # Select component
  if (exists $options{COMP} && defined $options{COMP}) {
    $optstring .= " COMP=$options{COMP}";
  }

  my $status;

  # A resetpars seems to be necessary to instruct kappa to
  # update its current frame for plotting. Without this the new PICDEF
  # regions are not picked up correctly.

  $status = $self->obj->resetpars;
  return $status if $status != ORAC__OK;
  
  # Do the obeyw
  $status = $self->obj->obeyw("contour", "device=$device ndf=$file $optstring accept ");
  if ($status != ORAC__OK) {
    orac_err("Error displaying contour\n");
    orac_err("Trying to execute: contour device=$device ndf=$file $optstring\n");
  }
  return $status;

}

=item B<sigma>

Display a scatter plot of the data with Y range of N-sigma (sigma
is derived from the data) with dashed lines overlaid at the X-sigma
points.

By default a range of +/-5 sigma with dashed lines at +/-3 sigma
are used.

These values can be overriden by using the RANGE and DASHED 
keywords.

Takes a file name and arguments stored in a hash.
Note that currently it does not take a format argument
and NDF is assumed.

If we are running KAPPA 0.13, the NDF is converted
to 1-DIM with the kappa RESHAPE command before 
displaying.

ORAC status is returned.

=cut

sub sigma {

  my $self = shift;
 
  my $file = shift;

  my %options = ();
  if (@_) {
    my $opt = shift;
    if (ref($opt) eq 'HASH') {
      %options = %{$opt};
    }
  }

  # Configure the display on the basis of REGION specifier
  # ..and return the selected device.
  # Return undef if something went wrong.
  my $device = $self->select_region(%options);

  # If device is now undef we have a problem
  unless (defined $device) {
    orac_err("Error configuring display for SIGMA. Possible invalid region designation\n");
    return ORAC__ERROR;
  }

  # Set the data file name
  $file =~ s/\.sdf$//;  # Strip .sdf
  my $tempfile; # Temp file if we reshape

  # Convert to 1-D using kappa RESHAPE (if we are using KAPPA0.13)
  # First find out the number of dimensions
  if ($KAPPA13) {
    my ($indf, $ndimx, $ndim, @dim);
    my $status = &NDF::SAI__OK;
    ndf_find(&NDF::DAT__ROOT, $file, $indf, $status);
    ndf_dim($indf, 7, @dim, $ndim, $status);
    if ($status != &NDF::SAI__OK) {
      err_annul($status);
      orac_err("Error reading num dims from input file: $file");
      return undef;
    }
    if ($ndim > 1) {
      # Reshape the NDF
      if ($self->ndfpack->contactw) {
	$tempfile = "dr_reshape$$";

	$status = $self->ndfpack->obeyw("reshape","in=$file out=$tempfile vectorize");
	if ($status != ORAC__OK) {
	  orac_err("Error reshaping data file to 1D\n");
	  return $status;
	}
	# Copy to $file
	$file = $tempfile;

      } else {
	orac_err("Error contacting ndfpack_mon\n");
	return ORAC__ERROR
      }

    }
  }

  # First thing to do is calculate the relevant statistics of the
  # input file.
  # Use kappa STATS

  # Select component
  my $args = '';
  if (exists $options{COMP} && defined $options{COMP}) {
    $args .= " COMP=$options{COMP}"; 
  }

  my $status;
  if ($self->kappa->contactw) {
    $status = $self->kappa->obeyw("stats","ndf=$file $args");
    if ($status != ORAC__OK) {
      orac_err("Error calculating statistics of data file\n");
      return $status;
    }
  } else {
    orac_err("Error contacting Kappa_mon\n");
    return ORAC__ERROR
  }

  # Now retrieve the answer
  my ($mean, $sigma);
  ($status,  $mean) = $self->kappa->get("stats","mean");
  if ($status != ORAC__OK) {
    orac_err "Error in ORAC::Display::KAPVIEW::sigma\n";
    orac_err("Error retrieving value of parameter MEAN from Kappa task STATS\n");
    return $status;
  }

  ($status, $sigma) = $self->kappa->get("stats","sigma");
  if ($status != ORAC__OK) {
    orac_err "Error in ORAC::Display::KAPVIEW::sigma\n";
    orac_err("Error retrieving value of parameter SIGMA from Kappa task STATS\n");
    return $status;
  }


  # Now need to check the options string
  my $range = 5.0;
  my $dashed = 3.0;

  $range = $options{RANGE} if (exists $options{RANGE});
  $dashed = $options{DASHED} if (exists $options{DASHED});

  # Now calculate the range of the plot
  my $max = $mean + ($range * $sigma);
  my $min = $mean - ($range * $sigma);

  # A resetpars also seems to be necessary to instruct kappa to
  # update its current frame for plotting. Without this the new PICDEF
  # regions are not picked up correctly. This may be fixed when 
  # running as an A-task rather than an I-task.

  $status = $self->obj->resetpars;
  return $status if $status != ORAC__OK;

  # Construct string for linplot options
  if ($KAPPA13) {
    $args = "clear mode=mark marker=2 ytop=$max ybot=$min";
  } else {
    $args = "clear mode=2 axlim=true ordlim=[$min,$max] abslim=!";
  }

  # Select component
  if (exists $options{COMP} && defined $options{COMP}) {
    $args .= " COMP=$options{COMP}";
  }

  # Run linplot
  $status = $self->obj->obeyw("linplot","ndf=$file device=$device $args");
  if ($status != ORAC__OK) {
    orac_err("Error displaying sigma plot\n");
    orac_err("Trying to execute: linplot ndf=$file device=$device $args\n");
    return $status;
  }

 
  # create args
  $args = "linestyle=2 sigcol=red nsigma=[0,$dashed]";

  # Select component
  if (exists $options{COMP} && defined $options{COMP}) {
    $args .= " COMP=$options{COMP}";
  }

  # run drawsig
  $status = $self->obj->obeyw("drawsig","device=$device $args");
  if ($status != ORAC__OK) {
    orac_err("Error overlaying lines\n");
    orac_err("Trying to execute: drawsig device=$device $args\n");
    return $status;
  }

  # unlink the tempfile
  unlink $tempfile .".sdf" if defined $tempfile;

  return $status;
}


=item B<datamodel>

Display mode where the supplied filename is plotted as individual
points and a model is overlaid as a solid line. This can be used
to determine the goodness of fit of data and model.

The model filename is derived from the input filename (a _model
extension is expected). The data is displayed if the model
file can not be found.

Takes a file name and arguments stored in a hash.
Note that currently it does not take a format argument
and NDF is assumed.

Option keywords:

  XMIN/XMAX  - X-pixel range of graph
  XAUTOSCALE - Autoscale pixel range?
  ZMIN/ZMAX  - Y-range of graph (in data units)
  ZAUTOSCALE - Autoscale Y-axis
  COMP       - Component to display (Data (default), Variance or Error)

Default is to autoscale on the data (the model may not be visible).

If the input file is greater than 1-D, the section is automatically
converted to 1-D by selecting the ?MIN slice from each of the
higher axes (eg the value specified in YMIN, 3min...)

ORAC status is returned.

=cut

sub datamodel {

  my $self = shift;
 
  my $file = shift;

  my %options = ();
  if (@_) {
    my $opt = shift;
    if (ref($opt) eq 'HASH') {
      %options = %{$opt};
    }
  }

  # Configure the display on the basis of REGION specifier
  # ..and return the selected device.
  # Return undef if something went wrong.
  my $device = $self->select_region(%options);

  # If device is now undef we have a problem
  unless (defined $device) {
    orac_err("Error configuring display for datamodel. Possible invalid region designation\n");
    return ORAC__ERROR;
  }

  # Set the data file name
  $file =~ s/\.sdf$//;  # Strip .sdf

  # Calculate NDF section - including compression of dimensions
  $file = $self->select_section($file,\%options,1);

  # A resetpars also seems to be necessary to instruct kappa to
  # update its current frame for plotting. Without this the new PICDEF
  # regions are not picked up correctly.

  my $status = $self->obj->resetpars;
  return $status if $status != ORAC__OK;

  # Calculate the range setting parameters
  my $range;
  if (exists $options{ZAUTOSCALE}) {
    if ($options{ZAUTOSCALE}) {
      if ($KAPPA13) {
	$range = " ";
      } else {
	$range = "axlim=false";
      }
    } else {
      # Set the Y range
      my $min = 0;
      my $max = 1;
      $min = $options{ZMIN} if defined $options{ZMIN};
      $max = $options{ZMAX} if defined $options{ZMAX};
      if ($KAPPA13) {
	$range = "ytop=$max ybot=$min";
      } else {
	$range = "axlim=true abslim=! ordlim=[$min,$max]";
      }    
    }
  }


  # Construct args
  my $args;
  if ($KAPPA13) {
    $args = "mode=mark marker=2 style='colour(marker)=white'";
  } else {
    $args = "cosys=data mode=2 symcol=white";
  }
  $args .= " clear $range";

  # Select component
  if (exists $options{COMP} && defined $options{COMP}) {
    $args .= " COMP=$options{COMP}";
  }

  # Now plot the data
  $status = $self->obj->obeyw("linplot","ndf=$file device=$device $args");
  if ($status != ORAC__OK) {
    orac_err("Error displaying data file\n");
    orac_err("Trying to execute: linplot ndf=$file device=$device $args\n");
    return $status;
  }

  # Now plot overlay the model if it is available
  my $model = $file . "_model";

  # Calculate the NDF section of the model
  $model = $self->select_section($model,\%options,1);

  if (-e $model . ".sdf") {  # Assume .sdf extension!!!!

    # Construct the arguments
    if ($KAPPA13) {
      $args = "mode=line style='colour(lines)=red'";
    } else {
      $args = "cosys=data mode=line lincol=red pltitl='' ordlab=''";
    }
    $args .= " noclear";

    # Select component
    if (exists $options{COMP} && defined $options{COMP}) {
      $args .= " COMP=$options{COMP}";
    }

    # Run linplot
    $status = $self->obj->obeyw("linplot","ndf=$model device=$device $args");
    if ($status != ORAC__OK) {
      orac_err("Error overlaying model\n");
      orac_err("Trying to execute: linplot ndf=$model device=$device $args\n");
      return $status;
    }
  }

  return $status;

}


=item B<histogram>

Display a histogram of the data values present in the 
data array.

Takes a file name and arguments stored in a hash.
Note that currently it does not take a format argument
and NDF is assumed.

Arguments:

  XMIN/MAX   - minimum/maximum x-pixel value
  XAUTOSCALE - Use full X-range
  YMIN/YMAX  - minimum/maximum x-pixel value
  YAUTOSCALE - use full Y-range
  ZMIN/ZMAX  - Z range of histogram (data units)
  ZAUTOSCALE - use full Z-range
  NBINS      - Number of bins to be used for histogram calculation
  COMP       - Component to display (Data (default), Variance or Error)

Default is for autoscaling and for NBINS=20.

ORAC status is returned.

=cut

sub histogram {
  my $self = shift;
 
  my $file = shift;

  my %options = ();
  if (@_) {
    my $opt = shift;
    if (ref($opt) eq 'HASH') {
      %options = %{$opt};
    }
  }

  # Configure the display on the basis of REGION specifier
  # ..and return the selected device.
  # Return undef if something went wrong.
  my $device = $self->select_region(%options);

  # If device is now undef we have a problem
  unless (defined $device) {
    orac_err("Error configuring display for histogram.\n Possible invalid region designation\n");
    return ORAC__ERROR;
  }

  # Set the data file name
  $file =~ s/\.sdf$//;  # Strip .sdf

  # Calculate NDF section
  $file = $self->select_section($file,\%options);

  # A resetpars also seems to be necessary to instruct kappa to
  # update its current frame for plotting. Without this the new PICDEF
  # regions are not picked up correctly.
  # May not be necessary if KAPVIEW is an A-task

  my $status = $self->obj->resetpars;
  return $status if $status != ORAC__OK;

  # THIS IS THE HISTOGRAM SPECIFIC STUFF

  # Should probably set the options
  # If we are autoscaling then we dont need any axis setting
  # default is not to send any axis control information
  # Just do Z-range for now

  my $range = "range=!";
  if (exists $options{ZAUTOSCALE}) {
    if ($options{ZAUTOSCALE}) {
      $range = "range=!";
    } else {
      # Set the Y range
      my $min = 0;
      my $max = 1;
      $min = $options{ZMIN} if defined $options{ZMIN};
      $max = $options{ZMAX} if defined $options{ZMAX};
      $range = "range=[$min,$max]";
    }
  }
  my $nbins = " NUMBIN=20";
  $nbins = " NUMBIN=$options{NBINS}" if exists $options{NBINS};

  # Construct string for linplot options
  my $args = "$range $nbins";

  # Select component
  if (exists $options{COMP} && defined $options{COMP}) {
    $args .= " COMP=$options{COMP}";
  }

  # Run histogram
  $status = $self->kappa->obeyw("histogram","in=$file device=$device $args accept");
  if ($status != ORAC__OK) {
    orac_err("Error displaying histogram\n");
    orac_err("Trying to execute: histogram ndf=$file device=$device $args accept\n");
    return $status;
  }

  return $status;
}


=item B<vector>

Vectors are overlaid on an image. The supplied file is displayed
and vectors are then drawn. The vector information is expected
to be stored in the ORAC extension of the supplied file
(in .P and .THETA NDFs) or, preferably, in a catalogue of the
same name as the I image. POLPLOT is used for display if
the catalogue is available.

Recognised options:

  XMIN/XMAX  - X pixel max and min values
  YMIN/YMAX  - Y pixel max and min values
  XAUTOSCALE - Use autoscaling for X?
  YAUTOSCALE - Use autoscaling for Y?
  ZMIN/ZMAX  - Z-range of greyscale (data units)
  ZAUTOSCALE - Autoscale Z?
  ANGROT     - angle to add to all vectors

Default is to autoscale.

ORAC status is returned.

=cut

sub vector {

  my $self = shift;
  my $file = shift;

  my %options = ();
  if (@_) {
    my $opt = shift;
    if (ref($opt) eq 'HASH') {
      %options = %{$opt};
    }
  }

  # Configure the display on the basis of REGION specifier
  # ..and return the selected device.
  # Return undef if something went wrong.
  my $device = $self->select_region(%options);

  # If device is now undef we have a problem
  unless (defined $device) {
    orac_err("Error configuring display for VECTORS. Possible invalid region designation\n");
    return ORAC__ERROR;
  }

  # Set the data file name
  $file =~ s/\.sdf$//;  # Strip .sdf

  # Run the image method with all arguments
  $self->image($file, \%options);

  my $status;
  # Look for a catalogue of the same name with a .FIT extension
  if (-e "$file.FIT" && defined $self->polpack) {
    # Using POLPLOT

    my $args = "clear=no axes=no ";
    if (exists $options{ANGROT} && defined $options{ANGROT}) {
      $args .= " ANGROT=$options{ANGROT}";
    }

    $status = $self->polpack->obeyw("polplot","cat=$file $args device=$device");

  } else {
    # Using VECPLOT

    # Select component
    my $args = "clear=no veccol=red step=2 vscale=10 pltitl=' '";
    if (exists $options{ANGROT} && defined $options{ANGROT}) {
      $args .= " ANGROT=$options{ANGROT}";
    }

    # Now run VECPLOT
    $status = $self->obj->obeyw("vecplot","ndf1=${file}.more.orac.p ndf2=${file}.more.orac.theta device=$device $args");

  }

  if ($status != ORAC__OK) {
    orac_err("Error displaying vectors\n");
    orac_err("Trying to execute: ndf1=${file}.more.orac.p ndf2=${file}.more.orac.theta clear=no device=$device veccol=red step=2 vscale=10\n");
    return $status;
  }

  return $status;
}


# DESTROY
# Remove the AGI file when we have finished with kapview

sub DESTROY {
   my $self = shift;
  
   # Construct the name of the AGI file
   my $fname = $AGI_USER . "/agi_" . $AGI_NODE . ".sdf";
   
   # Remove it
   unlink($fname);

}




=back

=head1 SEE ALSO

L<ORAC::Display>, L<ORAC::Display::GAIA>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)
and Frossie Economou  (frossie@jach.hawaii.edu)

=cut





1;



