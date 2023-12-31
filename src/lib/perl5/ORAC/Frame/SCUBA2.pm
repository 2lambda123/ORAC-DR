package ORAC::Frame::SCUBA2;

=head1 NAME

ORAC::Frame::SCUBA2 - SCUBA-2 class for dealing with observation files in ORACDR

=head1 SYNOPSIS

  use ORAC::Frame::SCUBA2;

  $Frm = new ORAC::Frame::SCUBA2("filename");
  $Frm = new ORAC::Frame::SCUBA2(@files);
  $Frm->file("file")
  $Frm->readhdr;
  $Frm->configure;
  $value = $Frm->hdr("KEYWORD");

=head1 DESCRIPTION

This module provides methods for handling Frame objects that
are specific to SCUBA-2. It provides a class derived from B<ORAC::Frame>.
All the methods available to B<ORAC::Frame> objects are available
to B<ORAC::Frame::SCUBA2> objects. Some additional methods are supplied.

=cut

# A package to describe a JCMT frame object for the
# ORAC pipeline

use 5.006;
use warnings;
use strict;
use Carp;

use ORAC::Constants;
use ORAC::Print;

use NDF;
use Starlink::HDSPACK qw/ retrieve_locs delete_hdsobj /;
use Starlink::AST;

use vars qw/$VERSION/;

# Let the object know that it is derived from ORAC::Frame::JCMT and
# ORAC::JSAFile
use base qw/ ORAC::JSAFile ORAC::Frame::JCMT /;

$VERSION = '1.0';

=head1 PUBLIC METHODS

The following are modifications to standard ORAC::Frame methods.

=head2 Constructors

=over 4

=item B<new>

Create a new instance of a B<ORAC::Frame::SCUBA2> object.  This method
also takes optional arguments: if 1 argument is supplied it is assumed
to be the name of the raw file associated with the observation but if
a reference to an array is supplied, each file listed in the array is
used. If 2 arguments are supplied they are assumed to be the raw file
prefix and observation number. In any case, all arguments are passed
to the configure() method which is run in addition to new() when
arguments are supplied.  The object identifier is returned.

   $Frm = new ORAC::Frame::SCUBA2;
   $Frm = new ORAC::Frame::SCUBA2("file_name");
   $Frm = new ORAC::Frame::SCUBA2(\@files);
   $Frm = new ORAC::Frame::SCUBA2("UT","number");

This method runs the base class constructor and then modifies
the rawsuffix and rawfixedpart to be '.sdf' and 's4' or 's8'
(depending on instrument designation) respectively.

=cut

sub new {

  my $proto = shift;
  my $class = ref($proto) || $proto;

  # Run the base class constructor with a hash reference
  # defining additions to the class
  # Do not supply user-arguments yet.
  # This is because if we do run configure via the constructor
  # the rawfixedpart and rawsuffix will be undefined.
  my $self = $class->SUPER::new();

  # Configure initial state - could pass these in with
  # the class initialisation hash - this assumes that I know
  # the hash member name
  $self->rawfixedpart('s' . $self->_wavelength_prefix );
  $self->rawsuffix('.sdf');
  $self->rawformat('NDF');
  $self->format('NDF');

  # If arguments are supplied then we can configure the object
  # Currently the argument will be the filename.
  # If there are two args this becomes a prefix and number
  $self->configure(@_) if @_;

  return $self;
}

=back

=head2 Subclassed methods

The following methods are provided for manipulating
B<ORAC::Frame::SCUBA2> objects. These methods override those
provided by B<ORAC::Frame>.

=over 4

=item B<configure>

Configure the frame object. Usually called from the constructor.

Can be called either with a single filename or a reference to an
array of filenames

  $Frm->configure( \@files );
  $Frm->configure( $file );

=cut

sub configure {
  my $self = shift;

  my @fnames;
  if ( scalar( @_ ) == 1 ) {
    my $fnamesref = shift;
    @fnames = ( ref($fnamesref) ? @$fnamesref : $fnamesref );
  } elsif ( scalar( @_ ) == 2 ) {

    # SCUBA-2 configure() cannot take 2 arguments.
    croak "configure() for SCUBA-2 cannot take two arguments";

  } else {
    croak "Wrong number of arguments to configure: 1 or 2 args only";
  }

  # Read the fits headers from all the raw files (since they should all have
  # .FITS)
  my %rfits;
  for my $f (@fnames) {
    my $fits;
    eval {
      $fits = new Astro::FITS::Header::NDF( File => $f );
      $fits->tiereturnsref(1);
    };
    if ($@) {
      # should not happen in real data but may happen in simulated
      # data
      $fits = new Astro::FITS::Header( Cards => []);
    }
    $rfits{$f}->{PRIMARY} = $fits;
  }

  # Set the filenames. Replace with processed images where appropriate
  my @paths;
  for my $f (@fnames) {
    my @internal = $self->_find_processed_images( $f );
    if (@internal) {
      push(@paths, @internal );
      # and read the FITS headers
      my @hdrs;
      for my $i (@internal) {

        my $fits;
        eval {
          $fits = new Astro::FITS::Header::NDF( File => $i );
          $fits->tiereturnsref(1);
        };
        if ($@) {
          # should not happen in real data but may happen in simulated
          # data
          $fits = new Astro::FITS::Header( Cards => []);
        }

        # Just store each one in turn. We can not index by a unique
        # name since I1 can be reused between files in the same frame
        push(@hdrs, $fits);

      }

      $rfits{$f}->{SECONDARY} = \@hdrs;

    } else {
      push(@paths, $f );
    }
  }

  # first thing we need to do is find which keys differ
  # between the .I1 and .IN processed images
  for my $f (keys %rfits) {

    # Rather than finding the unique keys of the primary and all the
    # secondary headers (Which may result in no headers that are
    # shared between primary and child) we first remove duplicate keys
    # from the child header and move them to the primary. In general
    # the secondary headers will either be completely unique keys
    # (otherwise they would be in the primary) or a complete copy
    # of the primary plus the unique keys.

    # in the former case, there will be no identical keys and so
    # nothing to merge into the PRIMARY header. In the latter, 95%
    # will probably be identical and that will probably be identical
    # to the bulk of the primary header.

    if (exists $rfits{$f}->{SECONDARY}) {
      # make sure we always return an entry in @different
      my ($secfirst, @secrest) = @{ $rfits{$f}->{SECONDARY} };
      my ($same, @different) = $secfirst->merge_primary( { force_return_diffs => 1},
                                                         @secrest );

      # differences should now be written to the SECONDARY array
      # since those are now the unique headers.
      $rfits{$f}->{SECONDARY} = \@different;

      # and merge the matching keys into the parent header
      # in this case, headers that are not present in either the child
      # or the primary header should be included in the merged header.
      my ($merged, $funique, $cunique) = $rfits{$f}->{PRIMARY}->merge_primary(
                                                                              {
                                                                               merge_unique => 1},
                                                                              $same );

      # Since we have merged unique keys into the primary header, anything
      # that is present in the "different" headers will be problematic since
      # it implies that we have headers that are present in both the .I
      # components and the primary header but that are identical between
      # the .I components yet different to the primary header. This is a
      # problem and we need to issue a warning.
      # Provide a special case for the OBSEND header since that is allowed to
      # differ in the very last entry when all others were 0. The above code expects
      # that frames that differ will differ in all .In headers.
      if (defined $funique || defined $cunique) {
        # remove OBSEND if present and TRUE trumps false for the global header
        my @remf = $funique->removebyname("OBSEND");
        my @remc = $cunique->removebyname("OBSEND");
        if (@remf && @remc) {
          my $oe = $merged->itembyname("OBSEND");
          if (defined $oe) {
            $oe->value(1);
          } else {
            #use Data::Dumper; print Dumper(\@remf,\@remc);
            $merged->insert( -1, $remf[0]);
            $remf[0]->value(1);
          }
        }

        if ($funique->sizeof > 0 && $cunique->sizeof > 0) {

          orac_warn("Headers are present in the primary FITS header of $f that clash with different values that are fixed amongst the processed components. This is not allowed.\n");

          orac_warn("Primary header:\n". $funique ."\n")
            if defined $funique;
          orac_warn("Component header:\n". $cunique ."\n")
            if defined $cunique;
        }
      }

      # Now reset the PRIMARY header to be the merge
      $rfits{$f}->{PRIMARY} = $merged;
    }
  }

  # Now we need to merge the primary headers into a single
  # global header. We do not merge unique headers (there should not be
  # any anyway) as those should be pushed back down

  # merge in the original filename order
  my ($preference, @pheaders) = map { $rfits{$_}->{PRIMARY} } @fnames;
  my ($primary, @different) = $preference->merge_primary( @pheaders );

  # The leftovers have to be stored back into the subheaders
  # but we also need to extract subheaders
  my $stored_good;
  my @subhdrs;
  for my $i (0..$#fnames) {
    my $f = $fnames[$i];
    my $diff = $different[$i];

    if (exists $rfits{$f}->{SECONDARY}) {


      # merge with the child FITS headers if required
      if (defined $diff) {
        $stored_good = 1;

        # if a header in the difference already exists in the SECONDARY
        # component we just drop it on the floor and ignore it. This
        # can happen if multiple subscans are combined each of which
        # has a DATE-OBS from the .I1 which differs from .I2 .. .In
        # The DATE-OBS in the primary header will differ in each subscan
        # but the .In value is the important value. Similarly for airmass,
        # elevation start/end values.
        for my $sec (@{$rfits{$f}->{SECONDARY}}) {
          for my $di ($diff->allitems) {
            # see if the keyword is present
            my $keyword = $di->keyword;
            my $index = $sec->index($keyword);

            if (!defined $index) { # index can be 0
              # take a local copy so that we do not get action at a distance
              my $copy = $di->copy;
              $sec->insert( -1, $copy );
            }
          }
          push(@subhdrs, $sec);
        }

      } else {
        # just store what we have (which may be empty)
        for my $h (@{$rfits{$f}->{SECONDARY}}) {
          $stored_good = 1 if $h->sizeof > -1;
          push(@subhdrs, $h);
        }
      }

    } else {
      # we only had a primary header so this is only defined if we have
      # a difference
      if (defined $diff) {
        $stored_good = 1; # indicate that we have at least one valid subhdr
        push(@subhdrs, $diff);
      } else {
        # store blank header
        push(@subhdrs, new Astro::FITS::Header( Cards => []));
      }
    }

  }

  # do we really have a subhdr?
  if ($stored_good) {
    if (@subhdrs != @paths) {
      orac_err("Error forming sub-headers from FITS information. The number of subheaders does not equal the number of file paths (".
               scalar(@subhdrs) . " != " . scalar(@paths).")\n");
    }
    $_->tiereturnsref(1) for @subhdrs;
    $primary->subhdrs( @subhdrs );
  }

  # Now make sure that the header is populated
  $primary->tiereturnsref(1);
  $self->fits( $primary );
  $self->calc_orac_headers;

  # register these files (will also fill in raw() )
  $self->files( @paths );

  # Find the group name and set it.
  $self->findgroup;

  # Find the recipe name.
  $self->findrecipe;

  # Find nsubs.
  $self->findnsubs;

  # Just return true.
  return 1;
}

=item B<framegroupkeys>

For SCUBA-2 a single frame object is returned in most cases. For focus
observations each focus position is returned as a separate Frame
object. This simplifies the recipes and allows the QL and standard
recipes to work in the same way.

Observation ID is also kept separate in case the pipeline gets so
far behind that the system detects the end of one observation and the
start of the next.

 @keys = $Frm->framegroupkeys;

=cut

sub framegroupkeys {
  return (qw/ OBSIDSS FOCPOSN FOCAXIS /);
}


=item B<file_from_bits>

Determine the raw data filename given the variable component
parts. A prefix (usually UT) and observation number should
be supplied.

  $fname = $Frm->file_from_bits($prefix, $obsnum);

Not implemented for SCUBA-2 because of the multiple files
that can be associated with a particular UT date and observation number:
the multiple sub-arrays (a to d) and the multiple subscans.

=cut

sub file_from_bits {
  my $self = shift;
  croak "file_from_bits Method not supported since the number of files per observation is not predictable.\n";
}

=item B<file_from_bits_extra>

Method to return C<extra> information to be used in the file name. For
SCUBA-2 this is a string representing the wavelength.  See also the
C<subsystem_id> method which currently returns the same thing but
with units included.

  my $extra = $Frm->file_from_bits_extra;

=cut

sub file_from_bits_extra {
  my $self = shift;
  return ( $self->hdr("FILTER") =~ /^8/ ) ? "850" : "450";
}

=item B<inout>

Acts like the base class C<inout> method unless the C<uhdr> entry
C<ALLOW_NUMBERED_SUFFICES> is set, in which case, if the file
already has a suffix including a 3-digit number, that number is
preserved in the suffix of the new file.

This is not quite the same as the corresponding method in the
ACSIS frame class because we don't assume that the number in
the suffix is the same as the file number within the frame -- there
could be multiple files with the same suffix number, e.g. from
different subarrays.

=cut

sub inout {
  my $self = shift;
  my $suffix = shift;
  my $number = shift;

  if ($self->uhdr('ALLOW_NUMBERED_SUFFICES')
      and $self->file($number // 1) =~ /_[a-z]+(\d\d\d)$/) {
    $suffix .= $1;
  }

  return $self->SUPER::inout($suffix, (defined $number ? $number : ()));
}

=item B<pattern_from_bits>

Determines the pattern for the flag file. This differs from other
instruments in that SCUBA-2 writes the flag files to ORAC_DATA_IN
but the data are written to completely distinct trees (not sub
directories of ORAC_DATA_IN).

  $pattern = $Frm->pattern_from_bits( $prefix, $obsnum );

Returns a regular expression object.

=cut

sub pattern_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  my $padnum = $self->_padnum( $obsnum );

  # Assume that ORAC_DATA_IN will not mix up 450 and 850 data
  my $pattern = $self->rawfixedpart . "[a-z]". $prefix . "_$padnum"
    . ".ok";

  return qr/$pattern$/;
}


=item B<number>

Method to return the number of the observation. The number is
determined by looking for a number after the UT date in the
filename. This method is subclassed for SCUBA-2 to deal with
SCUBA-2-specific filenames.

The return value is -1 if no number can be determined.

=cut

sub number {
  my $self = shift;
  my $number;

  my $raw = $self->raw;

  if ( defined( $raw ) ) {
    # Raw files as seen in raw data directory,
    # Flag files
    # Temp files written by pipeline in task mode
    if ( ( $raw =~ /^s[48]?[a-d]?\d{8}_(\d{5})_(\d{4})/ ) ||
         ( $raw =~ /_(\d{5})\.ok$/ ) ||
         ( $raw =~ /_(\d{5})_\d{4}\.sdf$/ ) ) {
      # Drop leading zeroes.
      $number = $1 * 1;
    } else {
      $number = -1;
    }
  } else {
    # No match so set to -1.
    $number = -1;
  }
  return $number;
}

=item B<subsystem_id>

Method to return the subsystem identifier. For
SCUBA-2 this is a string representing the wavelength.

  my $ssid = $self->subsystem_id();

=cut

sub subsystem_id {
  my $self = shift;
  return ( $self->hdr("FILTER") =~ /^8/ ) ? "850um" : "450um";
}

=item B<flag_from_bits>

Determine the flag filename given the variable component
parts. A prefix (usually UT) and observation number should
be supplied.

  @fnames = $Frm->file_from_bits($prefix, $obsnum);

Returns multiple file names (one for each array) and
throws an exception if called in a scalar context. The filename
returned will include the path relative to ORAC_DATA_IN, where
ORAC_DATA_IN is the directory containing the flag files.

The format is "swxYYYYMMDD_NNNNN.ok", where "w" is the wavelength
signifier ('8' for 850 or '4' for 450) and "x" a letter from
'a' to 'd'.

=cut

sub flag_from_bits {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  croak "flag_from_bits returns more than one flag file name and does not support scalar context (For debugging reasons)" unless wantarray;

  # Read the flag file names from the .meta file if it exists
  my $meta_file = $self->meta_file($prefix, $obsnum);
  if ( $meta_file ) {
    use ORAC::General qw/ read_file_list /;
    return read_file_list( $meta_file );
  } else {
    # pad with leading zeroes
    my $padnum = $self->_padnum( $obsnum );

    # get prefix
    my $fixed = $self->rawfixedpart();

    my @flags = map {
      $fixed . $_ . $prefix . "_$padnum" . ".ok"
      } ( $self->_dacodes );

    # SCUBA naming
    return @flags;
  }
}

=item B<findgroup>

Return the group associated with the Frame. This group is constructed
from header information. The group name is automatically updated in
the object via the group() method.

=cut

# Supply a new method for finding a group

sub findgroup {

  my $self = shift;

  # Extra information required for group disambiguation
  my $extra = $self->hdr("FILTER" );

  # Call the base class
  return $self->SUPER::findgroup( $extra );
}

=item B<get_files_by_subarray>

Return a hash with subarray names as keys and values containing a list
(array reference) of the associated file names.

  my %subarrayfiles = $Frm->get_files_by_subarray;

=cut

sub get_files_by_subarray {
  my $self = shift;
  return $self->files_from_hdr( "SUBARRAY" );
}

=item B<instap_subarray>

Return the name of the subarray which corresponds to the instrument
aperture at the current wavelength.

  my $data_instap = $Frm->instap_subarray;

=cut

sub instap_subarray {
  my $self = shift;
  # Retrieve current instrument aperture
  my $instap = $self->hdr("INSTAP");

  # Is the instrument aperture the same filter as the data?
  my $instap_wavelen = ($instap =~ /4/ ? 4 : 8);
  my $data_wavelen = ($self->hdr("FILTER") =~ /450/ ? 4 : 8);

  # If the instap is defined at the other waveband, work out which
  # subarray that maps to it this waveband. Fortunately it's simple:
  # the a and d subarrays are swapped, as are the b and c.
  if ($instap_wavelen != $data_wavelen) {
    my $new_instap = "s".($data_wavelen);
    $new_instap .= "d" if $instap =~ /a$/;
    $new_instap .= "c" if $instap =~ /b$/;
    $new_instap .= "b" if $instap =~ /c$/;
    $new_instap .= "a" if $instap =~ /d$/;
    $instap = $new_instap;
  }
  return $instap;
}

=item B<jsa_pub_asn_id>

Determine the association ID to be used for the JCMT Science Archive
to collect the "public" products.  This is written in plain text
as it will be short enough to not require an md5sum to be taken
as is the case for C<asn_id()>.

Currently the same as C<subsystem_id> but implemented separately
so that changes to one do not alter the other.

=cut

sub jsa_pub_asn_id {
  my $self = shift;
  return $self->hdr('FILTER') =~ /^8/ ? '850um' : '450um';

}

=item B<meta_file>

Search for and return the full path to the meta file associated with
the given observation. The meta file is written by the SCUBA-2 data
acquisition system and contains the name of the flag files (.ok) in
use. The naming convention is "sw_YYYYMMDD_NNNNN.meta", where "w" is
the wavelength signifier ('8' for 850 or '4' for 450).

Takes two mandatory arguments which are the file prefix (usually the
UT date) and the observation number. Returns undef if no such file
exists.

  my $meta_file = $self->meta_file( $prefix, $obsnum );

=cut

sub meta_file {
  my $self = shift;

  my $prefix = shift;
  my $obsnum = shift;

  # pad with leading zeroes
  my $padnum = $self->_padnum( $obsnum );

  # get prefix
  my $fixed = $self->rawfixedpart();

  my $mfile = $fixed . "_" . $prefix . "_$padnum" . ".meta";

  use File::Spec;
  my $meta_file = File::Spec->catdir($ENV{ORAC_DATA_IN}, $mfile);
  # Return full path to the .meta file
  if ( -e $meta_file ) {
    return $meta_file;
  } else {
    return undef;
  }
}

=item B<numsubarrays>

Return the number of subarrays in use. Works by checking for unique
subheaders and determining which of the abcd sub-arrays are producing
data. Only works once data are read in so ORAC-DR must have some other
way of knowing that there are n subarrays.

=cut

sub numsubarrays {
  my $self = shift;
  return scalar $self->subarrays;
}

=item B<rewrite_outfile_subarray>

This method modifies the supplied filename to remove specific subarray
designation and replace it with a generic filter designation. 4 digit
subscan information is also removed but not if this is a Focus
observation or if the data are a fast-ramp flatfield (as there may be
multiple fastflats in a single observation).

Should be used when subarrays are merged into a single file.

If the s8a/s4a designation is missing the filename will be returned
unchanged.

  $outfile = $Frm->rewrite_outfile_subarray( $old_outfile );

The output file, or output HDS extension in a container, will be
removed by this routine. If no HDS container exists and it looks like
one will be required, it is created.

=cut

sub rewrite_outfile_subarray {
  my $self = shift;
  my $old = shift;

  # see if we have a subarray designation
  my $new = $old;
  if ($old =~ /^s[48][abcd]/) {

    # filter information
    my $filt = $self->file_from_bits_extra;

    # Replace the subscan number with the filter name
    my $obsmode = $self->hdr( "OBS_TYPE" );
    my $seqtype = (defined $self->hdr( "SEQ_TYPE" ))
      ? $self->hdr( "SEQ_TYPE" ) : $obsmode;
    my $keep_subscan = shift;
    if ($obsmode =~ /focus/i || $seqtype =~ /fastflat/i || $keep_subscan) {
      $new =~ s/(_\d\d\d\d_)/$1${filt}_/;
    } else {
      $new =~ s/(_\d\d\d\d_)/_${filt}_/;
    }

    # remove the subarray designation
    $new =~ s/^s[48][abcd]/s/;

    # Get the suffix
    my ($bitsref, $suffix) = $self->_split_fname( $new );
    if (defined $suffix && length($suffix)) {
      # delete the output file so that it can be created fresh
      # each time. HDS containers seem to require that the out
      # component does not pre-exist. We either have to delete the
      # .I1 if it exists or delete the whole container

      # see if we have an output file
      my $root = $new;
      $root =~ s/\..*$//;
      if (!-e "$root.sdf") {
        # need to make the container
        # Create the new HDS container and name the root component after the
        # first 9 characters of the output filename
        my $status = &NDF::SAI__OK;
        err_begin($status);
        my @null = (0);
        hds_new ($root,substr($root,0,9),"ORACDR_HDS",
                 0,@null,my $loc,$status);
        dat_annul($loc, $status);
        err_end($status);
      } else {
        # make sure the child structure is not present
        # since HDS will complain if it tries to write to a
        # pre-existing component.
        delete_hdsobj( $new );
      }

    }

  }
  return $new;
}

=item B<strip_subscan>

Strip subscan number from supplied filename. This can be used when going
from a group of files from a single subarray to a file associated with
that subarray but no subscan.

 $new = $Frm->strip_subscan( $old );

=cut

sub strip_subscan {
  my $self = shift;
  my $new = shift;
  $new =~ s/_\d\d\d\d_/_/;
  return $new;
}

=item B<subarray>

Return the name of the subarray given either a filename or the index
into a Frame object. The subarray is also stored in the current Frame
uhdr. Takes a mandatory sole argument which is the file index or
name. If the Frame header has subheaders then the subarray is obtained
from the FITS header of the file rather than assuming the subheader
order is synchronized with that of the files. Returns undef if the
FITS header could not be retrieved.

  my $subarray = $Frm->subarray( $i );
  my $subarray = $Frm->subarray( $Frm->file($i) );
  $Frm->subarray( $file );

Works on the current frame only.

=cut

sub subarray {
  my $self = shift;

  # Check - if there are sub-headers then we need to delve further
  if ( exists $self->hdr->{'SUBHEADERS'} ) {
    # OK now check that there are SUBARRAY subheaders
    my @subhdrs = @{ $self->hdr->{SUBHEADERS} };
    if ( exists $subhdrs[0]->{SUBARRAY} ) {
      # If Subarray is present in the subheaders then we have to dig
      # deeper - now we take notice of the input argument
      my $inarg = shift;
      if ( !defined $inarg ) {
        orac_err "No input file: unable to determine subarray from subheaders\n";
      }
      my $subarray;

      # Does the input argument look like a number?
      my $file = ( $inarg =~ /^\d+/ ) ? $self->file( $inarg ) : $inarg;

      # Retrieve FITS header
      use Astro::FITS::Header::NDF;
      my $fitshdr = new Astro::FITS::Header::NDF( File => $file );
      if ( $fitshdr ) {
        $subarray = $fitshdr->value("SUBARRAY");
      } else {
        # Error...
        orac_warn "Unable to read FITS header for file $file - subarray unknown\n";
        $subarray = undef;
      }

      # Store in Frm uhdr if defined
      $self->uhdr("SUBARRAY", $subarray) if (defined $subarray);
    } else {
      # No subarray in subheaders, store subarray from header
      $self->uhdr("SUBARRAY", $self->hdr("SUBARRAY"));
    }
  } else {
    # No subheaders => only 1 subarray
    $self->uhdr("SUBARRAY", $self->hdr("SUBARRAY"));
  }
  return $self->uhdr("SUBARRAY");
}

=item B<subarrays>

Return a list of the subarrays associated with the current Frame
object. Searches the subheaders for presence of SUBARRAY keyword which
will be present if data from multiple subarrays are stored in the
current Frame. If not found then just use the SUBARRAY entry in the
hdr.

  @subarrays = $Frm->subarrays;

Returns an list. In scalar context returns the number of subarrays.

=cut

sub subarrays {
  my $self = shift;
  my @subarrays;

  # if we have a value in the primary header then we know there
  # can not be a subheader for it
  if (exists $self->hdr->{SUBARRAY} && defined $self->hdr->{SUBARRAY}) {
    push(@subarrays, $self->hdr( "SUBARRAY" ));
  } elsif ( exists $self->hdr->{'SUBHEADERS'} ) {
    # OK now check that there are SUBARRAY subheaders
    # if the first subheader has it then they all will
    my @subhdrs = @{ $self->hdr->{SUBHEADERS} };
    if ( exists $subhdrs[0]->{SUBARRAY} ) {
      my %subarrays;
      $subarrays{ $_->{SUBARRAY} }++ for @subhdrs;
      push(@subarrays, keys %subarrays);
    } else {
      # But if the subarray is not in the subheaders, store the
      # subarray from the hdr
      push(@subarrays, $self->hdr( "SUBARRAY" ));
    }
  }

  return wantarray() ? sort @subarrays : scalar(@subarrays);
}

=item B<makemap_args>

Return a list of supported arguments for makemap which may be
specified as recipe parameters. Returns array or array reference
depending on calling context.

  my @makemap_args = $Frm->makemap_args;

The supported arguments are (currently): alignsys, config, crota,
maxmem, method, pixsize, spread, system.

=cut

sub makemap_args {
  my $self = shift;
  my @makemap_args = qw/ config crota maxmem params pixsize ref spread system /;
  return (wantarray) ? @makemap_args : \@makemap_args;
}

=item B<get_fastramp_flats>

Retrieve files in the current Frame which have a sequence type of C<FASTFLAT>.

  my @fastramps = $Frm->get_fastramp_flats;

Returns an array, which will be empty if no fast-ramp flatfield files
could be found.

=cut

sub get_fastramp_flats {
  my $self = shift;

  my @fastflats;

  for my $i (1..$self->nfiles) {
    # Must use the hdrval method as sequence types can change during
    # an observation
    if ($self->hdrval("SEQ_TYPE",$i-1) =~ /FASTFLAT/i ) {
      push(@fastflats, $self->file($i));
    }
  }

  return @fastflats;
}

=item B<duration_science>

The difference between the end of the last science sequence and the
start of the first science sequence. This is not quite the same as the
duration of the observation because it will not include initial/trailing
darks and ramps.

  $dur = $Frm->duration_science();

Returns the duration in seconds.

To calculate the duration of the observation as a whole use ORAC_UTSTART
and ORAC_UTEND uhdrs.

=cut

sub duration_science {
  my $self = shift;

  my $mindate = undef;
  my $maxdate = undef;
  my $sequence_steps = 0;
  my $nscience = 0;

  require Astro::FITS::HdrTrans::FITS;
  for my $i (1..$self->nfiles) {
    # Must use the hdrval method as sequence types can change during
    # an observation and we have to parse the FITS format string.
    my $seq_type = $self->hdrval( "SEQ_TYPE", $i-1);
    my $obs_type = $self->hdrval( "OBS_TYPE", $i-1);

    # if we do not have a seq_type we assume it is obs_type
    # which won't be true for 2009 data.
    $seq_type = $obs_type unless defined $seq_type;

    if ($seq_type eq $obs_type) {
      $nscience++;

      my %headers = (
                     "DATE-OBS" => $self->hdrval("DATE-OBS", $i-1),
                     "DATE-END" => $self->hdrval("DATE-END", $i-1),
                    );
      my $date_obs_obj = Astro::FITS::HdrTrans::FITS->to_UTSTART( \%headers );
      my $date_end_obj = Astro::FITS::HdrTrans::FITS->to_UTEND( \%headers );

      my $nsteps = $self->hdrval("SEQEND", $i-1) - $self->hdrval("SEQSTART", $i-1);
      $sequence_steps += $nsteps;

      if (!defined $mindate || $mindate > $date_obs_obj) {
        $mindate = $date_obs_obj;
      }
      if (!defined $maxdate || $maxdate < $date_end_obj) {
        $maxdate = $date_end_obj;
      }
    }
  }

  # If still undef we did not get a real observation
  if (!defined $mindate || !defined $maxdate) {
    return 0;
  }

  # if we only had once science file look at the sequence counter
  if ($nscience == 1) {
    my $step = $self->hdrval( "STEPTIME", 0 );
    return ( $sequence_steps * $step );
  }

  return ($maxdate - $mindate);

}

=item B<filter_darks>

Standard image-based DREAM and STARE processing has no need for dark
frames and so these should be filtered out as early as possible to
prevent weird errors. The translated header for the observation mode
is used. From this point on, no dark frames will be returned unless
the user accesses the raw data.

  $Frm->filter_darks;

=cut

sub filter_darks {

  my $self = shift;

  # Filter out Dark frames from DREAM/STARE data
  if ( ($self->uhdr("ORAC_OBSERVATION_MODE") =~ /dream/ ||
        $self->uhdr("ORAC_OBSERVATION_MODE") =~ /stare/) &&
       $self->uhdr("ORAC_OBSERVATION_TYPE") !~ /flatfield/ ) {

    my (@darks, @nondarks);
    for my $i ( 1 .. $self->nfiles ) {
      if ( $self->hdrval("SHUTTER", $i-1) == 1.0 ) {
        push ( @nondarks, $self->file($i) );
      } else {
        push ( @darks, $self->file($i) );
      }
    }
    my $ndarks = $#darks + 1;
    my $dark = ($ndarks == 1) ? "dark" : "darks";
    orac_say "Removing $ndarks $dark from the current observation";
    $self->files( @nondarks );
  }

  return;
}

=back

=begin __INTERNAL_METHODS

=head1 PRIVATE METHODS

=over 4

=item B<_wavelength_prefix>

Return the relevent wavelength code that will be used to specify the
particular set of data files. An '8' for 850 microns and a '4' for 450
microns.

 $pre = $frm->_wavelength_prefix();

=cut

sub _wavelength_prefix {
  my $self = shift;
  my $code;
  if ($ENV{ORAC_INSTRUMENT} =~ /_850/) {
    $code = '8';
  } else {
    $code = '4';
  }
  return $code;
}

=item B<_dacodes>

Return the relevant Data Acquisition computer codes. Always a-d.

  @codes = $frm->_dacodes();
  $codes = $frm->_dacodes();

In scalar context returns a single string with the values concatenated.

=cut

sub _dacodes {
  my $self = shift;
  my @letters;

  # If the following environment variable is set then we are in QL
  # mode so split the list of tasks and pick out the dacodes
  if ( defined $ENV{ORAC_REMOTE_TASK} ) {
    my @tasks = split(/,/,$ENV{ORAC_REMOTE_TASK} );
    # HACK: pick out last letter of each task name
    foreach my $task ( @tasks ) {
      # Split on @ as QL is usually running on remote machines
      my @tsk = split(/@/, $task);
      # Add lower-cased last letter of taskname
      push (@letters, lc(substr($tsk[0],-1,1)) );
    }
  } else {
    @letters = qw/ a b c d /;
  }

  return (wantarray ? @letters : join("",@letters) );
}

=item B<_find_processed_images>

Some SCUBA-2 data files include processed images (specifically, DREAM
and STARE) that should be used as the pipeline input images in preference
to the time series.

This method takes a single file and returns the HDS hierarchy to these
images within the main frame. Returns empty list if no reduced images
are present.

=cut

sub _find_processed_images {
  my $self = shift;
  my $file = shift;

  # begin error context
  my $status = &NDF::SAI__OK;
  err_begin( $status );

  # create the expected path to the container
  $file =~ s/\.sdf$//;
  my $path = $file . ".MORE.SCU2RED";

  # forget about using NDF to locate the extension, use HDS directly
  ($status, my @locs) = retrieve_locs( $path, 'READ', $status );

  # if status is bad, annul what we have and return empty list
  if ($status != &NDF::SAI__OK) {
    err_annul( $status );
    dat_annul( $_, $status ) for @locs;
    err_end( $status );
    return ();
  }

  # now count the components in this location
  dat_ncomp($locs[-1], my $ncomp, $status);

  my @images;
  if ($status == &NDF::SAI__OK) {
    for my $i ( 1..$ncomp ) {
      dat_index( $locs[-1], $i, my $iloc, $status );
      dat_name( $iloc, my $name, $status );
      push(@images, $path . "." . $name) if $name =~ /^I\d+$/;
      dat_annul( $iloc, $status );
    }
  }
  dat_annul( $_, $status ) for @locs;
  err_annul( $status ) if $status != &NDF::SAI__OK;
  err_end( $status );

  return @images;
}

=back

=end __INTERNAL_METHODS

=head1 SEE ALSO

L<ORAC::Frame>, L<ORAC::Frame::NDF>

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 1998-2005 Particle Physics and Astronomy Research
Council. All Rights Reserved.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful,but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place,Suite 330, Boston, MA  02111-1307, USA

=cut

1;
