package ORAC::Group;

=head1 NAME

ORAC::Group - base class for dealing with observation groups in ORAC-DR

=head1 SYNOPSIS

  use ORAC::Group;

  $Grp = new ORAC::Group("group1");

  $Grp->file("Group_file_name");
  $group_name = $Grp->name;
  $Grp->push($frame);
  $total_in_group = $Grp->num;
  $frame3 = $Grp->frame(2);
  @good_members = $Grp->members;

=head1 DESCRIPTION

This module provides the basic methods available to all
B<ORAC::Group> objects. This class should be used when 
storing information relating to a group of observations
processed in the B<ORAC-DR> data reduction pipeline.

Groups are composed of frame objects (B<ORAC::Frame>)
or objects that can perform those methods.

=cut


# A package to describe the GROUP entity for the pipeline

use 5.006;
use Carp;
use strict;
use warnings;
use vars qw/$VERSION/;

'$Revision$ ' =~ /.*:\s(.*)\s\$/ && ($VERSION = $1);

# Associated classes
use ORAC::Print;          # Print statements
use ORAC::Index::Extern;  # For bad observation index list
use ORAC::Constants;

# Setup the object structure


=head1 PUBLIC METHODS

The following methods are available in this class.

=head2 Constructors

The following constructors are available:

=over 4

=item B<new>

Create a new instance of a B<ORAC::Group> object.
This method takes an optional argument containing the
name of the new group. The object identifier is returned.

   $Grp = new ORAC::Group;
   $Grp = new ORAC::Group("group_name");

The base class constructor should be invoked by sub-class constructors.
If this method is called with the last argument as a reference to
a hash it is assumed that this hash contains extra configuration
information ('instance' information) supplied by sub-classes.

=cut

# NEW - create new instance of Frame

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Check last arg for a hash
  my %subclass = ();
  %subclass = %{ pop(@_) } if (ref($_[-1]) eq 'HASH');

  # Define the initial state plus include any hash information
  # from a sub-class
  my $group = {
	       AllMembers => [],
	       BadObsIndex => undef,
	       Coadds => [],
	       File => undef,
	       FileSuffix => undef,
	       FixedPart => undef,
	       Header => {},
	       Members => [],
	       Name => undef,
	       RawName => undef,
	       Recipe => undef,
	       UHeader => {},
	       %subclass,
	      };

  bless($group, $class);

  # If an arguments are supplied then we can configure the object
  # Currently the argument will simply be the group name (ID)

  $group->name(shift) if @_;
  $group->raw(shift) if @_;

  return $group;
}

=item B<subgrp>

Method to return a new group (ie a sub-group of the existing
group) that contains all members of the main group matching
certain header values.

Arguments is a hash that is used for comparison with each
frame.

  $subgrp = $Grp->subgrp(NAME => 'CRL618', CHOP=> 60.0);

The new subgrp is blessed into the same class as $Grp.
All header information (hdr() and uhdr()) is copied 
from the main group to the sub-group.

This method is generally used where access to members of the
group by some search criterion is required.

It is possible that the returned group will contain no 
members....

=cut

sub subgrp {
  my $self = shift;

  # Read the input hash
  my %hash = @_;

  # Create a new grp
  my @subgrp = (); # Storage array
  my $parent_name = $self->name;
  $parent_name = 'UNKNOWN' unless defined $parent_name; # -w protection
  my $subgrp = $self->new($parent_name . "_subgrp");

  # Copy the header information
  %{$subgrp->hdr} = %{$self->hdr};
  %{$subgrp->uhdr} = %{$self->uhdr};

  # Now loop over all members of the group and compare with
  # the hash
  foreach my $member ($self->members) {

    my $match = 1;  # Assume a match

    # We are doing a string comparison
    foreach my $key (keys %hash) {
      unless (defined $hash{$key}) {
	orac_warn "SUBGRP: Key $key does not have a value in comparison hash\n";
      }
      # Need to check hdr() and uhdr()
      my $val1 = $member->hdr($key);
      my $val2 = $member->uhdr($key);

      unless (defined $val1 or defined $val2) {
	orac_warn "SUBGRP: Key $key is not defined in the header for $member\n";
      }

      # -w protection
      $val1 = '' unless defined $val1;
      $val2 = '' unless defined $val2;

      # Compare with the selected key
      unless ( ($hash{$key} eq $val1) or ($hash{$key} eq $val2)) {
        $match = 0;
        last;
      }
    }

    # If we have matched all keys then we push onto the subgrp
    # Use a temporary array for efficiency
    push(@subgrp, $member) if $match;

  }

  # Store the matched members in the sub group
  # If we do it this way we do not have to check group membership
  # (Since we know the frames are valid since they came from the
  # members() method)
  # but we do have to set members as well as allmembers

  @{ $subgrp->allmembers } = @subgrp;
  @{ $subgrp->members }    = @subgrp;

  return $subgrp;

}


=item B<subgrps>

Returns frames grouped by the supplied header keys.
A frame can not belong to more than one sub group created by this
method:

   @grps = $Grp->subgrps(@keys);

The groups in @grps are blessed into the same class as $Grp.
For example, if @keys = ('MODE','CHOP') then you can gurantee
that the members of each sub group will have the same values
for MODE and CHOP. 

All header information from the main group is copied to the
sub groups.

If a key is not present in the headers then all the frames
will be returned in a single subgrp (since that group guarantees
that the specified header item is not different - it simply
is not there).

=cut

sub subgrps {
  my $self = shift;
  my @keys = @_;

  # We can create a unique key in a hash for the header values
  # specified. So create a temporary hash.
  my %store = ();

  # Loop over all members of current group

  foreach my $member ($self->members) {
    # Create a key
    my $key = "";
    foreach my $hdr (@keys) {
      # We need to check in hdr() and uhdr()
      my $val1 = $member->hdr($hdr);
      my $val2 = $member->uhdr($hdr);
      if (defined $val1) {
	$key .= $val1;
      } elsif (defined $val2) {
	$key .= $val2;
      }
    }

    # Now see whether this key already exists in the hash
    # if it doesnt we populate it with a group object
    unless (exists $store{$key} ) {
      $store{$key} = $self->new();
      # Copy the header
      %{$store{$key}->hdr}  = %{$self->hdr};
      %{$store{$key}->uhdr} = %{$self->uhdr};
    }

    # Store the frame (this is inefficient since it
    # forces a check_membership every time and we know membership
    # is okay since members() only returns valid frames.
    $store{$key}->push($member);

  }

  # Return the values
  return values %store;
}



=back

=head2 Accessor methods

The following methods are available for accessing the 
'instance' data.

=over 4

=cut

# Create some methods to access "instance" data
#
# With args they set the values
# Without args they only retrieve values


=item B<allmembers>

Set or retrieve the array containing the current group membership.

    $Grp->allmembers(@frames);
    @frames = $Grp->allmembers;

The setting function of this routine should only be used
if you know what you are doing (since it completely changes the group
membership). If setting the contents, the check_membership() method
is run automatically so that the list of valid members can remain
synchronized.

All group members are returned regardless of the state of each member.
Use the members() method to return only valid members.

If called in a scalar context, a reference to an array is returned
rather than the array.

  $ref = $Grp->allmembers;
  $first = $Grp->allmembers->[0];

Do not use this array reference to change the contents of the array
directly unless the check_membership() method is run immediately
afterwards. The check_membership() method is responsible for 
checking the state of each member and copying them to the members()
array.

=cut

sub allmembers {
  my $self = shift;
  if (@_) { 
    @{ $self->{AllMembers} } = @_;
    $self->check_membership; # Check valid frames.
  }
  if (wantarray()) {
    return @{ $self->{AllMembers} };
  } else {
    return $self->{AllMembers};
  }
}

=item B<badobs_index>

Return (or set) the index object associate with the bad observation
index file. A index of class B<ORAC::Index::Extern> is used since 
this index is modified by an external user/program.

The index is created automatically the first time this method
is invoked.

=cut

sub badobs_index {

  my $self = shift;
  if (@_) { $self->{BadObsIndex} = shift }

  # If undef we can create a new index object
  unless (defined $self->{BadObsIndex}) {
    my $indexfile = $ENV{ORAC_DATA_OUT}."/index.badobs";
    my $rulesfile = $ENV{ORAC_DATA_CAL}."/rules.badobs";
    $self->{BadObsIndex} = new ORAC::Index::Extern($indexfile,$rulesfile);
  };

  return $self->{BadObsIndex}; 
}


=item B<coadds>

Return (or set) the array containing the list of frame numbers that have
been coadded into the current group. This is not necessarily the same
as the return of the membernumbers() method since that can return numbers
for all the members of the group even if the full coaddition has not
taken place or the pipeline has been resumed partway through a coaddition
(in which case the coadds array will contain more numbers than are in the
group).

  @coadds = $Grp->coadds;
  $coaddref = $Grp->coadds;
  $Grp->coadds(@numbers);

Returns an array reference in a scalar context, an array in an
array context.

The contents of this array are not automatically written to the 
group file when changed, see the coaddspush() or coaddswrite() methods
for further information on object persistence. The array is simply
meant as a storage area for the pipeline.

=cut

sub coadds {
  my $self = shift;
  if (@_) { @{$self->{Coadds}} = @_; }
  if (wantarray()) {
    return @{$self->{Coadds}};
  } else {
    return $self->{Coadds};
  }
}


=item B<file>

Set or retrieve the filename associated with the
reduced group.

    $Grp->file("group_filename");
    $group_file = $Grp->file;

Currently only one filename can be associated with the group
(although the method will accept, but ignore, a number supplied
as first argument so as to provide compatibility with the
display system).

If raw() is undefined, it is set to this value when the filename is updated.

=cut


# The default file method should be able to accept numbers
# If an integer is supplied then do nothing - simply return
# current value. This is added here so that the Display system
# can ask for multiple file names based on index - which
# is used by the Frames in some cases (eg SCUBA, MICHELLE). The Display
# sub-system does not distinguish between Groups and Frames
# so the shared methods have to be supported on both.

sub file {
  my $self = shift;
  if (@_) { 
    my $arg = shift;
    $self->{File} = $self->stripfname($arg)
      unless ($arg =~ /^\d+$/ && $arg != 0); 
    $self->raw($self->{File}) unless defined $self->raw;
  }
  return $self->{File};
}

=item B<filesuffix>

Set or retrieve the filename suffix associated with the
reduced group.

    $Grp->filesuffix(".sdf");
    $group_file = $Grp->filesuffix;

=cut


sub filesuffix {
  my $self = shift;
  if (@_) { $self->{FileSuffix} = shift;};
  return $self->{FileSuffix};
}

=item B<fixedpart>

Set or retrieve the part of the group filename that does not
change between invocation. The output filename can be derived using
this.

    $Grp->fixedpart("rg");
    $prefix = $Grp->fixedpart;

=cut


sub fixedpart {
  my $self = shift;
  if (@_) { $self->{FixedPart} = shift;};
  return $self->{FixedPart};
}



=item B<hdr>

This method allows specific entries in the header to be accessed.  In
general, this header is related to the actual header information
stored in the Group file. The input argument should correspond to the
keyword in the header hash.

  $tel = $Grp->hdr("TELESCOP");
  $instrument = $Grp->hdr("INSTRUME");

Can also be used to set values in the header.
A hash can be used to set multiple values (but does not overwrite
other keys).

  $Grp->hdr("INSTRUME" => "IRCAM");
  $Grp->hdr("INSTRUME" => "SCUBA", 
            "TELESCOP" => 'JCMT');

If no arguments are provided, the reference to the header hash
is returned.

  $Grp->hdr->{INSTRUME} = 'SCUBA';

The header can be populated from the file by using the readhdr()
method.

=cut


sub hdr {
  my $self = shift;

  # If we have one argument we should read it and return the associated
  # value. If we have more than one argument will assume a hash has
  # been supplied and append it to the existing values.
  if (@_) {
    if (scalar(@_) == 1) {
      my $key = shift;
      return $self->{Header}->{$key};
    } else {

      # Assume we are setting keys, append to the existing
      # hash. Can either do this by merging the two hashes
      # (inefficient since we have to take an entire copy
      # of the existing hash) or by looping through the supplied
      # keys and changing them one by one. The former is more 
      # efficient for large lists, the latter when only supplying
      # a few arguments. For programming simplicity will take
      # the former approach

      %{ $self->{Header} } = ( %{ $self->{Header} }, @_ );
    }
  } else {
    # No arguments, return the header hash reference
    return $self->{Header};
  }
}

=item B<members>

Retrieve the array containing the valid objects within the group

    @frames = $Grp->members;

This is the safest way to access the group members
since it only returns valid frames to the caller.

Use the allmembers() method to return all members of the group 
regardless of the state of the individual frames.

Group membership should not be set using ths method since that may lead
to a situation where the actual membership of the group does not match the
selected membership. [Valid group membership should only be set from
within this class].

If called in a scalar context, a reference to an array is returned
rather than the array.

  $first = $Grp->members->[0];

=cut

sub members {
  my $self = shift;
  @{ $self->{Members} } = @_ if @_;
  if (wantarray()) {
    return @{ $self->{Members} };
  } else {
    return $self->{Members};
  }
}


# Return/set the current file name of the object
# Make sure that the extension is not present

=item B<name>

Set or retrieve the name of the group (ie the 
group identifier)

    $Grp->name("group_name");
    $group_name = $Grp->name;

=cut


sub name {
  my $self = shift;
  if (@_) { $self->{Name} = shift; }
  return $self->{Name};
}

=item B<raw>

This method returns (or sets) the name of the raw data file
associated with this object. In the context of a group, it is
the name of the group file before any group level processing is
done.

  $Grp->raw("raw_data");
  $filename = $Grp->raw;

=cut

sub raw {
  my $self = shift;
  if (@_) { $self->{RawName} = shift; }
  return $self->{RawName};
}


=item B<uhdr>

This method allows specific entries in the user-defined header to be 
accessed. The input argument should correspond to the keyword in the header
hash.

  $tel = $Grp->uhdr("Telescope");
  $instrument = $Grp->uhdr("Instrument");

Can also be used to set values in the header.
A hash can be used to set multiple values (but does not overwrite
other keys).

  $Grp->uhdr("Instrument" => "IRCAM");
  $Grp->uhdr("Instrument" => "SCUBA", 
             "Telescope" => 'JCMT');

If no arguments are provided, the reference to the header hash
is returned.

  $Grp->uhdr->{Instrument} = 'SCUBA';

=cut


sub uhdr {
  my $self = shift;

  # If we have one argument we should read it and return the associated
  # value. If we have more than one argument will assume a hash has
  # been supplied and append it to the existing values.
  if (@_) {
    if (scalar(@_) == 1) {
      my $key = shift;
      return $self->{UHeader}->{$key};
    } else {

      # Assume we are setting keys, append to the existing
      # hash. Can either do this by merging the two hashes
      # (inefficient since we have to take an entire copy
      # of the existing hash) or by looping through the supplied
      # keys and changing them one by one. The former is more 
      # efficient for large lists, the latter when only supplying
      # a few arguments. For programming simplicity will take
      # the former approach

      %{ $self->{UHeader} } = ( %{ $self->{UHeader} }, @_ );
    }
  } else {
    # No arguments, return the header hash reference
    return $self->{UHeader};
  }
}


=back

=head2 General methods

The following methods are provided for manipulating B<ORAC::Group>
objects:

=over 4

=item B<calc_orac_headers>

This method calculates header values that are required by the
pipeline by using values stored in the header.

Required ORAC extensions are:

ORACTIME: should be set to a decimal time that can be used for
comparing the relative start times of frames. For IRCAM this
number is decimal hours, for SCUBA this number is decimal
UT days.

ORACUT: This is the UT day of the frame in YYYYMMDD format.

This method should be run after a header is set. Currently the header()
method calls this whenever it is updated.

The base class automatically generates the ORAC_ headers and 
should be invoked by sub-classes.

=cut

sub calc_orac_headers {
  my $self = shift;

  my %new = ();  # Hash containing the derived headers

  # Now create all the ORAC_ headers
  # go through an array of headers and translate the
  # ones we can find with associated methods
  my @ORAC_ = (qw/
               AIRMASS_START
               AIRMASS_END
               DECBASE
               FILTER 
               INSTRUMENT 
               LBNDX 
               LBNDY
               NOFFSETS 
               OBJECT 
               OBSERVATION_NUMBER
               OBSTYPE 
               RABASE 
               READMODE
               ROTATION 
               SPD_GAIN 
               UBNDX 
               UBNDY 
               WPLANGLE 
               DECSCALE 
               DET_BIAS 
               EXP_TIME 
               GAIN 
               RASCALE
               TDECOFF 
               TRAOFF 
               UTEND 
               UTSTART
               CONFIGURATION_INDEX
               DETECTOR_INDEX
               DETECTOR_MODE
               DIM1
               DIM2
               GRATING_NAME
               GRATING_ORDER
               GRATING_WAVELENGTH
               NSCAN_POSITIONS
               NUMBER_OF_EXPOSURES
               SCAN_INCREMENT
               SLIT_ANGLE
               SLIT_NAME
               STANDARD
               UTDATE
               /);

  # Loop over all the headers
  # Do nothing if a translation method does not exist
  # This makes it safe for everyone
  for my $key ( @ORAC_ ) {
    my $method = "_to_$key";
    #print "Trying method $method\n";
    if ($self->can($method)) {
      #print "Running method $method\n";
      # This returns a single value
      $new{"ORAC_$key"} = $self->$method();
      $self->uhdr("ORAC_$key", $new{"ORAC_$key"});
    }
  }

  return %new;
}

=item B<check_membership>

Check whether any of the members of the group have been marked for
removal from the group. The valid group members are copied
to a new array and can be retrieved by the members() method.
Note that all group methods use the list of valid group
members.

This routine is automatically run whenever the group membership
is updated (via the push() or  allmembers() methods. This may
cause too high an overhead with push() in, for example, the
subgrps method).

This method works by looking in a text file created by the
observer in $ORAC_DATA_OUT called index.badobs. This file
contains a list of numbers (two per line) relating to observations
that should be turned off. The first number is the UT date
(YYYYMMDD) and the second number is the observation
number. This is necessary so that ORAC_DATA_OUT can be reused
for a different UT date without worrying about the index file
file turning off incorrect observations.

The UT and observation number are compared with each member of
the group (the full list of members - see allmembers()).
For each group member, the following test is performed to test
for validity. First it is queried to check whether it is in a
good state (ie has been processed successfully). 
A frame will be marked as bad if the recipe fails to execute
successfully. If the frame is good (from the pipeline viewpoint)
the UT date and observation number is then compared with the
entries in the index file. If a match can B<NOT> be found the
frame is considered to be valid and is copied to the list of valid
group members (see the members() method).

The format of the index file should be of the form:

 24 19980716 
 27 19980716 
 43 19980815 
 ...

=cut

sub check_membership {
  my $self = shift;

  # Array of good frames
  my @good = ();

  # Need to loop over all members of the group
  foreach my $member ($self->allmembers) {

    # First need to see whether the the frame is in a valid
    # state -- no point continuing if not valid

    next unless UNIVERSAL::can($member, 'isgood');

    if ($member->isgood) {

      # Now compare the current frame with the bad observation
      # index list. This routine will return undef if there was
      # no match [ie a good file] and an index key if the file
      # was bad (the first matching key is returned)
      # Note that we have to make sure that the keys are in
      # alphabetical order (not very clever) since this is the
      # order constrained by the Index class and must match the
      # order used in the user-supplied index file

      my $badobs = 
          $self->badobs_index->cmp_with_hash({
					      ORACNUM => $member->number,
					      ORACUT => $member->hdr('ORACUT')
					     });

      # if the $badobs is not defined then we have a good observation
      unless (defined $badobs) {
	push (@good, $member);
      } else {
	orac_warn "Removing observation ". $member->number ." from group\n";
      }

    }

  }

  # Update the good members list
  $self->members(@good);

}

=item B<coaddspush>

Used to push observation numbers onto the coadds() array. Automatically
runs coaddswrite() to update to sync the file contents with the coadds()
array.

  $Grp->coaddspush(@numbers);

=cut

sub coaddspush {
  my $self = shift;
  if (@_) {
    push( @{$self->coadds}, @_);
    $self->coaddswrite;
  }
}

=item B<coaddspresent>

Compares the contents of the coadds() array with the supplied (single)
argument. Returns true if the argument is present in the coadds()
array, false otherwise. Also, returns false if no arguments are supplied
or if the argument is undef.

  $present = $Grp->coaddspresent($number);

=cut

sub coaddspresent {
  my $self = shift;
  if (@_) {
    my $arg = shift;
    if (defined $arg) {
      # Use grep to search through the coadds array
      # return true if the number is present
      # else return false at the end of the routine
      return 1 if grep { /^$arg$/ } @{$self->coadds};
    }
  }
  return 0;
}

=item B<coaddsread>

Reads the coadds() information from the current group file and stores
it in the group using the coadds() method.
Should return ORAC__OK if the coadds information was read successfully,
else returns ORAC__ERROR.

This is an abstract method and should be defined by a subclass.

=cut

sub coaddsread {
  print "ERROR: ATTEMPTING TO READ COADDS ARRAY USING BASE CLASS\n";
}

=item B<coaddswrite>

Method to write the contents of the coadds() array to the current
group file. Should return ORAC__OK if the coadds information was written
successfully, else returns ORAC__ERROR.

If coadds() contains no entries, all coadds information is removed from
the group file if present.

This is an abstract method and should be defined by a subclass.

=cut

sub coaddswrite {
  print "ERROR: ATTEMPTING TO WRITE COADDS ARRAY USING BASE CLASS\n";
}

=item B<erase>

Erases the group file from disk.

   $Grp->erase;

Returns ORAC__OK if successful, ORAC__ERROR otherwise.

=cut

sub erase {
  my $self = shift;
  my $status = unlink $self->file;

  return ORAC__ERROR if $status == 0;
  return ORAC__OK;
}


=item B<file_exists>

Method to determine whether the group file() exists on disk or not.
Returns true if the file is there, false otherwise. Effectively
equivalent to using C<-e> but allows for the possibility that the
information stored in file() does not directly relate to the
file as stored on disk (e.g. a .sdf extension).

=cut

sub file_exists {
  my $self = shift;
  if (-e $self->file) {
    return 1;
  }
  return 0;
}


=item B<file_from_bits>

Method to return the group filename derived from a fixed
variable part (eg UT) and a group designator (usually obs
number). The full filename is returned (including suffix).

  $file = $Grp->file_from_bits("UT","num");

For the base class the return string is of the format

  fixedpart . prefix . '_' . number . suffix

For example, with IRCAM using a UT date of 980104 and observation
number 25 the returned string would be 'rg980104_25.sdf'.

=cut

sub file_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $num = shift;

  # Follow UKIRT style
  return $self->fixedpart . $prefix . '_' . $num . $self->filesuffix;

}

=item B<frame>

Retrieve the nth frame of the group.
Counting starts at 0 as for a standard perl array.

  $Frm = $Grp->frame(2);

This is equivalent to

  $Frm = $Grp->members->[2];

A second argument can be used to set the nth frame.

  $Grp->frame(3, $Frm);

Note that this replaces the nth frame in the list of valid members and
also replaces the equivalent frame in the list of all members of the
group. This is done since the nth valid member is not necessarily the
nth group member. If the supplied position is greater than the current
number of members the supplied frame is simply pushed onto the
array. Remember that just because a frame has been inserted into the
group does not necessarily mean that it will be a valid member
(check_membership() will be run when setting any member of the group).
If the current frame at the specified position can not be found in
allmembers() the supplied frame is pushed onto allmembers() and
membership is re-checked.

=cut

sub frame {

  my $self = shift;

  my $number = shift;

  # Seems that we are setting the value
  # We need to be clever here
  if (@_) { 
    my $new = shift;
    # If the number is greater than the current number of members
    # just do a push
    if ($number > scalar(@{$self->members}) ) {
      $self->push($new);
    } else {
      # Retrieve the current member of the group
      my $current = $self->members->[$number];

      # Search through allmembers looking for this frame
      # and replace it
      my $replace = 0; 

      if (defined $current) {
	foreach my $frm ($self->allmembers) {
	  if ($frm eq $current) {
	    $frm = $new;
	    $replace = 1;
	    last;
	  }
	}
      }

      # If we have not found the value push this frame 
      # using a low-level push to prevent us running
      # check_membership twice
      push(@{$self->allmembers}, $new) unless $replace;

      # Check membersip
      $self->check_membership;
    }
  }
  # Return the value
  return $self->members->[$number];
}


=item B<inout>

Method to return the current filenames for each frame in the
group (similar to the membernames() method) and a set of output
names for each file. This is achieved by calling the inout()
method for each frame in turn. This will fail if the members of the
group do not possess the inout() method.

This method can take two arguments: the new suffix and, optionally,
the file number to use (see the inout() documentation for
B<ORAC::Frame>). References to two arrays are returned when called
in an array context; returns the output array ref when called
from a scalar context

  ($inref, $outref) = $Grp->inout("suffix");
  ($inref, $outref) = $Grp->inout("suffix",2);
  $outref= $Grp->inout("suffix");

=cut

sub inout {

  my $self = shift;

  # Find the suffix
  my $suffix = shift;

  # Read the file number if supplied
  my $num = (scalar(@_) ? shift : 1);

  # Initialise the output arrays
  my @in = ();
  my @out = ();

  # Now loop over the members
  foreach my $member ($self->members) {

    # Retrieve the input and output names of these files
    my ($in, $out) = $member->inout($suffix,$num);
    push(@in, $in);
    push(@out, $out);

  }

  # Return the array references
  if (wantarray()) {
    return \@in, \@out;
  } else {
    return \@out;
  }
}


=item B<lastmember>

Method to determine whether the supplied argument
matches the last member of the group. Returns a 1 if
it is the last member and a zero otherwise.

   $islast = $Grp->lastmember($Frm);

=cut

sub lastmember {
  my $self = shift;
  my $member = shift;

  if ($member eq $self->frame($self->num)) {
    return 1;
  }

  return 0;
}

=item B<membernames>

Return a list of all the files associated with the group. This is
achieved by invoking the file() method for each object stored in the
Members array.  For this to work each member must be an object capable
of invoking the file() method (e.g. B<ORAC::Frame>). Currently the
routine does not check to make sure this is possible - the program
will die if you try to use a SCALAR member.

If an argument list is given the file names for each member of the
group are updated. This will only be attempted if the number of 
arguments given matches the number of members in the group.

  $Grp->membernames(@newnames);
  @names = $Grp->membernames;

Only the first file from each frame object is returned.

=cut

sub membernames {

  my $self = shift;

  # If arguments are supplied use the values to update the
  # filenames in each frame
  if (@_) {
    # Only attempt this if the number of arguments supplied matches
    # The number of members in the group
    if ($self->num == $#_) {
      foreach my $member ($self->members) {
	my $newname = shift;
	$member->file($newname);
      }
    }

  }

  # Now return the list of names associated with each member
  my @list = ();
  foreach my $member ($self->members) {

    push(@list, $member->file);

  }
  return @list;
}

=item B<membernumbers>

Return a list of all the observation numbers associated with
the group. This is achieved by invoking the number() method for
each object stored in the Members array.
For this to work each member must be an object capable of invoking
numbers() (e.g. B<ORAC::Frame>). Currently the routine does not check
to make sure this is possible - the program will die if you try
to use a SCALAR member.

  @numbers = $Grp->membernumbers;

=cut

sub membernumbers {

  my $self = shift;

  my @list = ();
  foreach my $member ($self->members) {

    push(@list, $member->number);

  }
  return @list;
}

=item B<membertagset>

Set the tag in each of the members.

  $Grp->membertagset( 'TAG' );

Runs the C<tagset> method on each of the member frames.

=cut

sub membertagset {
  my $self = shift;
  if (@_) {
    foreach my $member ($self->members) {
      $member->tagset($_[0]);
    }
  }
}

=item B<membertagretrieve>

Run the C<tagretrieve()> method for each of the members.

  $Grp->membertagretrieve

=cut

sub membertagretrieve {
  my $self = shift;
  if (@_) {
    foreach my $member ($self->members) {
      $member->tagretrieve($_[0]);
    }
  }
}

# Method to return the number of frames in a group
# Same style as for $#array.

=item B<num>

Return the number of frames in a group minus one.
This is identical to the $# construct.

  $number_of_frames = $Grp->num;

=cut

sub num {
  my $self = shift;
  return $#{$self->members};
}



# Method to push data onto the group
# Multiple members can be added in one go

=item B<push>

Method to push an observation into the group. Multiple observations
can be pushed on at once (see L<perl> "push()" command).

  $Grp->push("observation2");
  $Grp->push(@obs);

There are no return arguments.

=cut

sub push {
  my $self = shift;
  if (@_) {
    push(@{ $self->allmembers }, @_);
    # Check frame membership
    $self->check_membership;
  }
}

=item B<readhdr>

A method that is used to read header information from the group
file. This method does nothing by default since the base
class does not know the format of the file associated with an
object.

The calc_orac_headers() method is called automatically.

=cut


sub readhdr {
  my $self = shift;
  $self->calc_orac_headers;
  return;
}

=item B<template>

Method to change all the current filenames in the group so that they
match the supplied template. This method invokes the template()
method for each member of the group.

  $Grp->template("filename_template");

A second argument can be specified to modify the specified frame
number rather than simply the first (see the template() method
in B<ORAC::Frame> for more details):

  $Grp->template($template,2);

There are no return arguments. The intelligence for this method resides
in the individual frame objects.

=cut

sub template {
  my $self = shift;

  # Loop over the members
  foreach my $member ($self->members) {
    $member->template(@_);
  }
}


=item B<updateout>

This method updates the current filename of each member of the group
when supplied with a suffix (and optionally, a file number -- see the
inout() method in B<ORAC::Frame> for more information). The inout() 
method (of the individual frame) is invoked for each member to 
generate the output name.

  $Grp->updateout("suffix");
  $Grp->updateout("suffix", 5);

This can be used to update the member filenames after an operation
has been applied to every file in the group. Alternatively the 
membernames() method can be invoked with the output of the inout()
method.

=cut

sub updateout {
  my $self = shift;
  my $suffix = shift;

  # Read the file number if supplied
  my $num = (scalar(@_) ? shift : 1);
  
  # Now loop over the members
  foreach my $member ($self->members) {

    my ($in, $out) = $member->inout($suffix,$num);
    $member->file($out);
  }

  return 1;
}



#=item reduce
#
#Method to return all members of the group that should be processed
#during the current pipeline loop. Currently this always returns
#the last member of the group (ie most recent addition).
#The intention is that this method is modified when necessary so that
#it returns a list of all frames that should be rereduced
#
#=cut
#
#sub reduce {
#  my $self = shift;


#
#  return $self->frame($self->num);
#  
#}





=back

=head1 DISPLAY COMPATIBILITY

These methods are provided for compatibility with the ORAC display
system.

=over 4

=item B<gui_id>

Returns the identification string that is used to compare the
current frame with the frames selected for display in the
display definition file.

In the default case, this method returns everything after the
last suffix stored in file().

In some derived implementation of this method an argument
may be used so that multiple IDs can be extracted from objects
that contain more than one output file per observation.

=cut

sub gui_id {
  my $self = shift;

  my $fname = $self->file;

  # Split on underscore
  my (@split) = split(/_/,$fname);

  return $split[-1];

}

=item B<nfiles>

This method is used by the display system to determine the
number of files to display. Since the Group base class can only
ever contain one file name (as returned by file()) this method
always returns a 1.

=cut

sub nfiles {
  return 1;
}


=item B<translate_hdr>

Translates an ORAC-DR specific header (such as ORAC_TIME)
to the equivalent FITS header(s).

  %fits = $Grp->translate_hdr( "ORAC_TIME" );

In some cases a single ORAC-DR header can be decomposed into 
multiple FITS headers (for example for SCUBA, ORAC_TIME is
a combination of the UTDATE and UTSTART). The hash returned
by translate_hdr() will include all the key/value pairs required
to generate the ORAC header.

This method will be called automatically to update hdr() values
ORAC_ keywords are updated via uhdr().

Returns an empty list if no translation is available.

=cut

sub translate_hdr {
  my $self = shift;
  my $key = shift;
  return () unless defined $key;

  # Remove leading ORAC_
  $key =~ s/^ORAC_//;

  # Each translation is performed by an individual method
  # This adds a overhead for method lookups but hopefully
  # will lend itself to subclassing
  # The translate_hdr() method itself will then not need to be 
  # subclassed at all
  my $method = "_from_$key";
  # print "trying method translate $method\n";
  if ($self->can($method)) {
    return $self->$method();

  } else {
    return ();
  }
}



=back

=head1 PRIVATE METHODS

The following methods are intended for use inside the module.
They are included here so that authors of derived classes are 
aware of them.

=cut

# Private method for removing file extensions from the filename strings
# In the base class this does nothing. It is up to the derived classes
# To do something special with this.

=over 4

=item B<stripfname>

Method to strip file extensions from the filename string. This method
is called by the file() method. For the base class this method
does nothing. It is intended for derived classes (e.g. so that ".sdf"
can be removed). Granted that I could simply force the "file" method
to be modified for derived classes....(which is why this method is
private).

=cut

sub stripfname {

  my $self = shift;
  my $name = shift;
  return $name;
}


=back

=head1 SEE ALSO

L<ORAC::Frame>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
and Frossie Economou  E<lt>frossie@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.


=cut

1;
