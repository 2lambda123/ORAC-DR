package ORAC::BaseNDF;

=head1 NAME

ORAC::BaseNDF - Base class for NDF file manipulation

=head1 SYNOPSIS

  use base qw/ ORAC::BaseNDF /;


=head1 DESCRIPTION

This class provides base methods for use by classes that need to
manipulate NDF files. For example, C<ORAC::Frame::NDF> and
C<ORAC::Group::NDF>.

=cut

use 5.006;
use strict;
use warnings;

use Carp;
use NDF;
use Astro::FITS::Header::NDF;
use ORAC::Error qw/ :try /;
use ORAC::Constants qw/ :status /;
use ORAC::Print;
use DateTime;
use DateTime::Format::Strptime;
use Starlink::Versions qw/ starversion_global /;
use ORAC::Version;

use vars qw/ $VERSION $DEBUG /;

$VERSION = '1.0';

$DEBUG = 0;

# We have NDF so we have HDSPACK so it is safe to define an error
# handler here so that the error stack is visible to ORAC-DR. All NDF
# usingi nstruments should inherit from this class
use Starlink::HDSPACK '2.01';
&Starlink::HDSPACK::error_handler( sub { my $cmd = shift; orac_err("$cmd: ". $_."\n") for @_ } );

=head1 METHODS

=head2 General Methods

=over 4

=item B<collate_headers>

This method is used to collect all of the modified FITS headers for a
given Frame object and return an updated C<Astro::FITS::Header> object
to be used by the C<sync_headers> method.

  my $header = $Frm->collate_headers( $file );

Takes one argument, the filename for which the header will be
returned.

=cut

sub collate_headers {
  my $self = shift;
  my $file = shift;

  return unless defined( $file );
  if ( $file !~ /\.sdf$/ ) {
    $file .= ".sdf";
  }
  return unless -e $file;

  my $header = new Astro::FITS::Header;
  $header->removebyname( 'SIMPLE' );
  $header->removebyname( 'END' );

  my @items;

  my ( $pstring, $pcommit, $pcommitdate ) = ORAC::Version::oracversion_global();
  # Update the version headers.
  my $pipevers = new Astro::FITS::Header::Item( Keyword => 'PIPEVERS',
                                                Value   => $pcommit,
                                                Comment => 'Pipeline version',
                                                Type    => 'STRING' );

  # We assume Starlink is the Engine if we are using NDF
  my ($vstring, $commit, $commitdate) = starversion_global();
  my $engvers = new Astro::FITS::Header::Item( Keyword => 'ENGVERS',
                                               Value   => $commit,
                                               Comment => 'Algorithm engine version',
                                               Type    => 'STRING' );

  # Need to choose most recent commit date - converted to number
  my $procvers_value;
  if ($commitdate && $pcommitdate) {
    $procvers_value = ( $commitdate > $pcommitdate ?
                        $commitdate->strftime( "%Y%m%d%H%M%S" ) :
                        $pcommitdate->strftime( "%Y%m%d%H%M%S" ) );
  } else {
    my @sys;
    push(@sys, "pipeline") unless defined $pcommitdate;
    push(@sys, "engine") unless defined $commitdate;
    print STDERR "Problem reading ".join(" and ",@sys)." version information\n";
  }
  my $procvers = new Astro::FITS::Header::Item( Keyword => 'PROCVERS',
                                                Value   => $procvers_value,
                                                Comment => 'Date of most recent commit',
                                                Type    => 'STRING' );

  # Calculate the new data reduction recipe header. This is only done
  # if the generic header exists
  my $uhdr = $self->uhdr;
  if (exists $uhdr->{ORAC_DR_RECIPE}) {
    my %cleaned = Astro::FITS::HdrTrans::clean_prefix( $uhdr, "ORAC_" );
    my $class = Astro::FITS::HdrTrans::determine_class( \%cleaned, undef, 0 );
    my %fits = $class->from_DR_RECIPE( \%cleaned );

    # At this point we should be updating the hdr() values but we do
    # not want to do that here because this method returns a new
    # header that is appended (with replace) to the hdr(). The trick
    # is to retain comments from the original FITS header whilst also
    # working within the paradigm of this merthod. To do that we need
    # the FITS header not the tie. A bit more convoluted than one
    # would expect. Other options is to do all this in an explicit
    # "work on $self->hdr" method.
    if (keys %fits) {
      my $fitshdr = $self->fits;
      for my $keyword (keys %fits) {
        my $ori = $fitshdr->itembyname( $keyword );
        if (defined $ori) {
          my $new = $ori->copy;
          $new->value( $fits{$keyword} );
          push(@items, $new);
        }
      }
    }
  }

  push(@items, $pipevers, $engvers, $procvers );

  # Insert the PRODUCT header. This comes from the $self->product
  # method. If the return value from this method is undefined, do not
  # insert the header.
  my $product = $self->product;
  if ( defined( $product ) ) {
    my $prod = new Astro::FITS::Header::Item( Keyword => 'PRODUCT',
                                              Value   => $product,
                                              Comment => 'Pipeline product',
                                              Type    => 'STRING' );
    push(@items, $prod );
  }

  $header->append( \@items );

  return $header;
}

=item B<readhdr>

Reads the header from the observation file (the filename is stored in
the object).  This method sets the header in the object (in general
that is done by configure() ).

    $Frm->readhdr;

The filename or filenames can be supplied if the one stored in the object
is not required:

    $Grp->readhdr($file);

but the header in $Frm is over-written. If multiple files are in the frame
or if multiple filenames are given the header information will be merged.
Merged headers will be stored as subheaders and accessible in the hash
interface via $Frm->hdr->{SUBHEADERS}->[n]. By default only data that
differs will be in a subheader.

An options hash as first argument can be used to override the default
behaviour. Specifically if a single file is given (or stored in the
object) but it contains multiple NDF components, the headers can be
returned such that the component named HEADER or largest header is the
primary and the subheaders are stored by component name.

  $Frm->readhdr( { nomerge => 1 }, $filename );

The subheaders will then be accessible as $Frm->hdr->{I1} (if the
component is called "I1").

All existing header information is lost. The C<calc_orac_headers()>
method is invoked once the header information is read.
If there is an error during the read a reference to an empty hash is
returned.

Currently this method assumes that the reduced group is stored in
NDF format. Only the FITS header is retrieved from the NDF.

If used as a class method, the filename(s) must be supplied
and calc_orac_headers() will not be called.

Returns the FITS header object.

=cut

sub readhdr {

  my $self = shift;

  my $is_class_method = (ref $self ? 0 : 1);

  # get the options hash
  my $opts;
  $opts = shift if ref($_[0]);

  # get the files
  my @files;
  if (@_) {
    @files = @_;
  } else {
    if (!$is_class_method) {
      @files = $self->files;
    } else {
      croak "Can not call readhdr() as class method without supplying file names";
    }
  }

  Carp::confess( "Asked to read header from zero files!" ) unless @files;

  my $Error;

  # Just read the NDF fits headers
  my $hdr;
  try {

    # Locate NDFs inside HDS containers
    my @ndfs = $self->_find_ndf_children( @files );

    my $suffixa = ( @files != 1 ? "s" : "");
    my $suffixb = ( @ndfs != 1 ? "s" : "");

    die "We were given ".@files." file$suffixa but asked to open ".scalar(@ndfs).
      " header$suffixb!" if @ndfs == 0;

    # are we merging? The option for not merging is only relevant
    # if we have one input file that becomes
    # multiple ndf components.
    my $domerge = 1;
    if (@files == 1 && @ndfs > 1) {
      $domerge = ($opts->{nomerge} ? 0 : 1);
    }

    # Read the headers. We have an explicit for loop so that we can
    # catch failures in single read rather than aborting all reads
    my %hdrs;
    my @errors;
    for my $f (@ndfs) {
      eval {
        $hdrs{$f} = Astro::FITS::Header::NDF->new( File => $f );
      };
      if ($@) {
        push(@errors, "Error reading FITS header of file $f", $@);
      }
    }

    # if we got errors but did not succeed in reading a single header
    # then abort
    if (!keys %hdrs) {
      if (@errors) {
        die "Error from read of header: ".join("\n",@errors);
      } else {
        die "Unexpectedly failed to read any headers from ".scalar(@ndfs)." NDF files";
      }
    }

    # to merge or not to merge
    if ($domerge) {
      # Now merge into the first - note that the order is important
      # here as subheaders need to be linked to file order for later
      # retrieval so create the @hdrs array by hand rather than simply
      # grabbing the values of the %hdrs hash.
      my @hdrs = map { $hdrs{$_} } @ndfs;
      $hdr = shift(@hdrs);
      if (@hdrs) {
        my ($merged, @different) = $hdr->merge_primary( {merge_unique=>1}, @hdrs);
        $merged->subhdrs( @different );
        $hdr = $merged;
      }
    } else {
      # need to decide on a primary header.
      # Special case - choose one that ends in HEADER
      my $primhdr;
      for my $k (keys %hdrs) {
        if ($k =~ /\.HEADER$/) {
          $primhdr = $k;
          last;
        }
      }

      # else choose the largest header as the primary
      if (!defined $primhdr) {
        my $biggest_key;
        my $maxncards = 0;
        for my $k (keys %hdrs) {
          my $sz = $hdrs{$k}->sizeof;
          if ($sz > $maxncards) {
            $maxncards = $sz;
            $biggest_key = $k;
          }
        }
        die "Internal error finding largest header" if !defined $biggest_key;
        $primhdr = $biggest_key;
      }

      # select the primary
      $hdr = $hdrs{$primhdr};
      delete $hdrs{$primhdr};

      # now assign the subheaders
      for my $k (sort keys %hdrs) {
        my $name = (split(/\./,$k))[-1]; # split on dot and take suffix
        my $item = Astro::FITS::Header::Item->new( Keyword => $name,
                                                   Value => $hdrs{$k});
        $hdr->insert(-1, $item);
      }

    }

    # Mark it suitable for tie with array return of multi-values
    $hdr->tiereturnsref(1);

    # And store it in the object
    $self->fits( $hdr ) unless $is_class_method;
  } otherwise {
    $Error = shift;
  };
  if ( defined( $Error ) ) {
    ORAC::Error->flush;
    throw ORAC::Error::FatalError( "$Error" );
  }
  ;

  # calc derived headers
  $self->calc_orac_headers() unless $is_class_method;

  return $hdr;
}

=item B<sync_headers>

This method is used to synchronize FITS headers with information
stored in e.g. the World Coordinate System.

  $Frm->sync_headers;
  $Frm->sync_headers(1);

This method takes one optional parameter, the index of the file to
sync headers for. This index starts at 1 instead of 0. If a non-number
is given it is assumed to be the name of a file.

Headers are only synced if the value returned by C<allow_header_sync>
is true.

=cut

sub sync_headers {
  my $self = shift;

  return unless $self->allow_header_sync;

  my $index;

  if ( @_ ) {
    $index = shift;
  }

  my @files;

  if ( defined $index ) {
    if ($index =~ /^\d+$/) {
      push @files, $self->file( $index );
    } else {
      @files = ($index);
    }
  } else {
    @files = $self->files;
  }

  # Get a list of known raw files
  # Need to do the stripfname shenanigans in case raw has a suffix
  my %rawlut = map { $self->stripfname($_), undef } $self->raw;

  foreach my $file ( @files ) {

    if ( !exists $rawlut{$file}) { # Do not update a raw file
      my $newheader = $self->collate_headers( $file );
      my $header = new Astro::FITS::Header::NDF( File => $file );
      $header->append( $newheader );
      $header->writehdr( File => $file );

    }
  }
}

=item B<read_wcs>

Read the frameset and store the resulting C<Starlink::AST> object into the
object for later retrieval via the C<wcs()> method.

  $Frm->read_wcs();

If a file name or filenames are provided the default behaviour is over-ridden and the frameset
is only read for the provided files. The resultant framesets are returned without being
stored in the object.

  $wcs = $Frm->read_wcs( $file );

In scalar context the first WCS object is returned.

=cut

sub read_wcs {
  my $self = shift;

  my $store_wcs;
  my @files;
  if (@_) {
    @files = @_;
  } else {
    @files = $self->files;
    $store_wcs = 1;
  }

  my $status = &NDF::SAI__OK;
  err_begin($status);
  ndf_begin();

  my @wcs;
  my $i = 0;
  for my $f ( @files ) {
    $i++;

    # Retrieve the WCS from the NDF.
    ndf_find(&NDF::DAT__ROOT(), $f, my $indf, $status);
    my $wcs = ndfGtwcs( $indf, $status );
    ndf_annul($indf, $status);

    if ($status != &NDF::SAI__OK) {
      err_annul($status);
      next;
    }

    # store it if we are supposed to
    push(@wcs, $wcs);
    $self->wcs( $i, $wcs ) if $store_wcs;
  }

  ndf_end($status);
  err_end($status);

  return (wantarray ? @wcs : $wcs[0] );
}

=item B<write_wcs>

Write the frameset back into the NDF.

  $Frm->write_wcs( $frameset );

If a file name or filenames are provided the default behaviour is over-ridden and the frameset
is only read for the provided files. The resultant framesets are returned without being
stored in the object.

  $wcs = $Frm->write_wcs( $file );

In scalar context the first WCS object is returned.

=cut

sub write_wcs {
  my $self = shift;
  my $frameset = shift;

  my @files;
  if (@_) {
    @files = @_;
  } else {
    @files = $self->files;
  }
  my $status = &NDF::SAI__OK;
  err_begin($status);
  ndf_begin();
  my $i = 0;
  for my $f ( @files ) {
    $i++;
#    print "File=$f\n";
    ndf_open( &NDF::DAT__ROOT(), $f, 'UPDATE', 'OLD', my $ndf_id, my $place, $status );

    if ($status != &NDF::SAI__OK) {
      err_annul($status);
      next;
    }
    ndfPtwcs( $frameset, $ndf_id, $status );
    ndf_annul( $ndf_id, $status );

  }
  # extract error messages and annul error status
  ndf_end($status);
#  if( $status != &NDF::SAI__OK ) {
#    my ( $oplen, @errs );
#    do {
#      err_load( my $param, my $parlen, my $opstr, $oplen, $status );
#      push @errs, $opstr;
#    } until ( $oplen == 1 );
#    err_annul( $status );
#    err_end( $status );
#    orac_error "Error writing new WCS to NDF:\n" . join "\n", @errs;
#  }
  err_end( $status );
}

=item B<flush_messages>

Flush any pending oracdr log messages to the history block of the associated
file or files. Each file in the object is modified. Only new history is written to the file.

  $Frm->flush_messages();
  $Grp->flush_messages();

Specifying a reference epoch will mean that only a log messages since that
epoch will be considered.

  $Frm->flush_messages( $refepoch );

=cut

sub flush_messages {
  my $self = shift;
  my $refepoch = shift;
  my @files = $self->files();

  # get the log messages (assume we reuse the global Print object)
  my @messages = orac_msglog($refepoch);

  # create a hash indexed by LOGKEY+EPOCH pointing to each message
  my %PENDING;
  for my $msg (@messages) {
    # put date first to aid sorting
    my $hashkey = sprintf("%.3f", $msg->[1] ) . $msg->[0];
    $PENDING{$hashkey} = $msg;
  }

  # Date parser for NDF
  my $Strp = DateTime::Format::Strptime->new(
                                             locale => 'C',
                                             pattern => '%Y-%b-%d %H:%M:%S',
                                             time_zone => 'UTC',);

  my $status = &NDF::SAI__OK;
  err_begin($status);
  ndf_begin();
  for my $f (@files) {
    # open the file for READ
    ndf_find( &NDF::DAT__ROOT(), $f, my $indf, $status );

    # find out how many history records there are, read them and
    # put flags in a hash indexed by application name and date
    ndf_hnrec( $indf, my $nrec, $status );

    # local copy
    my %towrite = %PENDING;
    # go through the records in reverse order so we can stop
    # early if our reference epoch is passed (since we know history
    # is stored in date order)
    for my $i (reverse 1..$nrec) {
      # from our point of view application and date are enough
      # to test.
      ndf_hinfo( $indf, 'DATE', $i, my $value, $status );

      # Strip fraction and parse
      my $frac = 0;
      if ($value =~ s/(\.\d+)$// ) {
        $frac = $1;
      }
      ;
      my $dt = $Strp->parse_datetime( $value );
      my $epoch = $dt->epoch;
      $epoch += $frac;

      if (defined $refepoch && $epoch < $refepoch) {
        last;
      }

      # need the application name
      ndf_hinfo( $indf, 'APPLICATION', $i, $value, $status );
      my $hashkey = sprintf( "%.3f", $epoch ) . $value;

      print "Read key from history in NDF file: $hashkey\n" if $DEBUG;

      # if this is in the pending list remove it since we do not need
      # to write it.
      delete $towrite{$hashkey} if exists $towrite{$hashkey};
    }

    # can now close the file that we opened for READ access
    ndf_annul( $indf, $status );

    # anything left in %towrite needs to be written to the file
    if (keys %towrite) {
      # open for update. NDF requires that you have to open and close
      # the file for each HISTORY update otherwise it combines the
      # ndf_hput information into a single history field.

      for my $msg (sort values %towrite) {
        ndf_open( &NDF::DAT__ROOT, $f, 'UPDATE', 'OLD', my $indf, my $place,
                  $status );

        print "Processing message...\n" if $DEBUG;
        # set update date - datetime() ignores nanosecond
        my $dt = DateTime->from_epoch( time_zone => 'UTC',
                                       epoch => $msg->[1] );
        my $str = $dt->datetime();
        my $nano = sprintf("%.3f",$dt->nanosecond() / 1E9);
        $nano =~ s/^0//;
        $str .= $nano;
        ndf_hsdat( $str, $indf, $status );

        # Form the block of text describing the recipe/primitive
        my %info = %{$msg->[3]};
        my @header;
        for my $key (sort keys %info) {
          my $value = $info{$key};
          $value = "<undefined>" unless defined $value;
          push(@header, "$key: $value");
        }
        print "Appn: ".$msg->[0]." ($str)\n" if $DEBUG;
        print "  HEADER=\n".join("\n",@header),"\n\n" if $DEBUG;
        print "  Message: ".join("\n",@{$msg->[2]})."\n" if $DEBUG;

        # Merge with the header, indenting the messages by 1
        # for consistency with NDF default history
        my @lines = @header;
        if (@{$msg->[2]}) {
          push(@lines, "Messages:");
          for my $l (@{$msg->[2]}) {
            push(@lines, " $l");
          }
        }

        ndf_hput( 'NORMAL', $msg->[0], 1, scalar(@lines), @lines,
                  0, 0, 0, $indf, $status );

        ndf_annul( $indf, $status );
      }

    }

    last if $status != &NDF::SAI__OK;
  }

  my $errstr;
  if ($status != &NDF::SAI__OK) {
    $errstr = &NDF::err_flush_to_string( $status );
  }

  ndf_end( $status );
  err_end( $status );
  orac_throw($errstr) if defined $errstr;
}

=item B<set_app_name>

A class method that is used to set the NDF application name from the
supplied arguments. Usually triggered automatically on entry to
a new primitive.

  $File->set_app_name( Primitive => $primitive );

Call without arguments to reset the name to the ORAC-DR app name and
version number.

=cut

sub set_app_name {
  my $self = shift;
  my %args = @_;
  my $status = &NDF::SAI__OK();

  my $baseapp = ORAC::Version->getApp;

  # Use the shortened SHA1 commit if available
  my @vers = ORAC::Version->oracversion_global;
  my $sha = "";
  $sha = "(". substr($vers[1],0,6).")" if defined $vers[1];

  my $extra = "";
  if (exists $args{Primitive} && defined $args{Primitive}) {
    $extra = "- $args{Primitive}";
  }

  NDF::ndf_happn( "$baseapp $extra $sha", $status );
}

=item B<fullfname>

Convert the supplied string to the actual file on disk. This would be
a string stored in the files() attribute. HDS components are removed
from the name and ".sdf" is added.

  $full = $Frm->fullfname( $file );

=cut

sub fullfname {
  my $self = shift;
  my $file = shift;

  # Strip anything after the first dot, in case extension is present.
  $file =~ s/\..*$//;
  return $file . ".sdf";
}

=back

=head1 PRIVATE METHODS

The following methods are intended for use inside the module.
They are included here so that authors of derived classes are
aware of them.

=over 4

=item B<stripfname>

Method to strip file extensions from the filename string. This method
is called by the file() method. We strip all extensions of the
form ".sdf", ".sdf.gz" and ".sdf.Z" since Starlink tasks do not require
the extension when accessing the file name if Convert has been
started.

=cut

sub stripfname {

  my $self = shift;

  my $name = shift;

  # Strip everything after the first dot
  $name =~ s/\.(sdf)(\.gz|\.Z)?$//
    if defined $name;

  return $name;
}

=item B<_find_ndf_children>

Given an array of filenames, open each one using HDS and see whether
there are any top level NDFs inside.

 @paths = $frm->_find_ndf_children( @files );

If a filename looks like it includes an HDS path (ie a file suffix
that is not ".sdf") it will be returned unmodified without being opened.

Options can be used to control behaviour if the first argument is a reference
to a hash

 @paths = $frm->_find_ndf_children( { compnames => 1}, $file );

If the "compnames" options is true only the names of component NDFs
within an HDS structure will be returned, rather than the filename
with paths.

=cut

sub _find_ndf_children {
  my $self = shift;
  my $opts = {};
  $opts = shift(@_) if ref($_[0]) eq 'HASH';
  my @files = @_;

  my @out;
  for my $f (@files) {
    $f =~ s/\.sdf$//;
    if ($f =~ /\./) {
      # has an unrecognized extension
      push(@out, $f) unless $opts->{compnames};
      next;
    }

    # open the file
    # Now need to find the NDFs in the output HDS file
    my $status = &NDF::SAI__OK;
    err_begin($status);
    hds_open($f, 'READ', my $loc, $status);

    # find the type - if it is an NDF just store it and try the next
    dat_type($loc, my $type, $status);

    # if the type is blank this may be SCUBA data but we need to check for DATA_ARRAY
    # These were early NDF data.
    if ($type eq '') {
      dat_there( $loc, "DATA_ARRAY", my $isthere, $status);
      $type = 'NDF' if $isthere;
    }

    if ($status == &NDF::SAI__OK) {
      if ($type eq 'NDF') {
        push(@out,$f) unless $opts->{compnames};
      } else {

        # Find out how many we have
        dat_ncomp($loc, my $ncomp, $status);

        # Get all the component names
        for my $i (1..$ncomp) {

          # Get locator to component
          dat_index($loc, $i, my $cloc, $status);

          # get the type
          dat_type( $cloc, my $ctype, $status);

          if ($ctype eq 'NDF') {

            # Find its name
            dat_name($cloc, my $name, $status);

            my $result = $name;
            $result = $f.".$name" unless $opts->{compnames};
            push(@out, $result) if $status == &NDF::SAI__OK;
          }

          # Release locator
          dat_annul($cloc, $status);

          last if $status != &NDF::SAI__OK;
        }
      }
    }

    dat_annul($loc, $status);

    if ($status != &NDF::SAI__OK) {
      my $errstr = err_flush_to_string( $status );
      err_end($status);
      croak "Error examining NDF children of file $f: $errstr\n";
    }

    err_end($status);
  }

  return @out;
}

=back

=head1 NOTES

This class must be in the class hierarchy ahead of the base frame
class (C<ORAC::BaseFile>) so that the C<readhdr> method is
picked up correctly.

=head1 SEE ALSO

L<ORAC::Frame::NDF>, L<ORAC::Group::NDF>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt>
and Frossie Economou  E<lt>frossie@jach.hawaii.eduE<gt>

=head1 COPYRIGHT

Copyright (C) 2007-2008 Science and Technology Facilities Council.
Copyright (C) 1998-2007 Particle Physics and Astronomy Research
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
