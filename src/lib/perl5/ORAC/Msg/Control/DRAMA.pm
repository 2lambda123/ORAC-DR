package ORAC::Msg::Control::DRAMA;

=head1 NAME

ORAC::Msg::Control::DRAMA - control and initialise DRAMA messaging from ORAC-DR

=head1 SYNOPSIS

  use ORAC::Msg::Control::DRAMA;

  $drama = new ORAC::Msg::Control::DRAMA(1);
  $drama->init;

=head1 DESCRIPTION

Methods to initialise the DRAMA messaging system and control the
behaviour.

=head1 METHODS

The following methods are available:

=cut

use 5.006;
use warnings;
use strict;
use Carp;
use ORAC::Print;
use ORAC::Constants qw/ :status /;

use vars qw/$VERSION $DRAMA_OBJECT /;

$VERSION = sprintf("%d", q$Revision$ =~ /(\d+)/);

use DRAMA;

=head1 METHODS

=head2 Constructor

=over 4

=item B<new>

Create a new instance of Starlink::AMS::Init.
If a true argument is supplied the messaging system is also
initialised via the init() method.

This class returns a singleton object.

=cut

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # return the cached object if it is defined
  return $DRAMA_OBJECT if defined $DRAMA_OBJECT;

  # create the hash for the object and bless it
  my $drama = bless {
		     Running => 0,
		     STDERR => \*STDERR,
		     STDOUT => \*STDOUT,
		     MESSAGES => 1,
		     ERRORS => 1,
		     TIMEOUT => 30,
	      }, $class;


  # Deal with the true argument
  if (@_) {
    my $value = shift;
    if ($value) {
      my $status = $drama->init;
      orac_throw("Error starting DRAMA message system\n") if $status != ORAC__OK;
    }
  }

  $DRAMA_OBJECT = $drama;
  return $drama;
}

=back

=head2 Accessor Methods

=over 4

=item B<running>

Returns true if the message system has been initialised, false otherwise.

=cut

sub running {
  my $self = shift;
  return $self->{Running}
}

=item B<messages>

Method to set whether standard messages returned from monoliths
are printed or not. If set to true the messages are printed
else they are ignored.

  $current = $drama->messages;
  $drama->messages(0);

Default is to print all messages.

=cut

sub messages {
  my $self = shift;
  if (@_) {
    $self->{MESSAGES} = shift;
  }
  return $self->{MESSAGES};
}

=item B<errors>

Method to set whether error messages returned from monoliths
are printed or not. If set to true the errors are printed
else they are ignored.

  $current = $drama->errors;
  $drama->errors(0);

Default is to print all messages.

=cut

sub errors {
  my $self = shift;
  if (@_) {
    $self->{ERRORS} = shift;
  }
  return $self->{ERRORS};
}

=item B<timeout>

Set or retrieve the timeout (in seconds) for some of the DRAMA messages.
Default is 30 seconds.

  $drama->timeout(10);
  $current = $drama->timeout;

=cut

sub timeout {
  my $self = shift;
  if (@_) {
    $self->{TIMEOUT} = shift;
  }
  return $self->{TIMEOUT};
}

=item B<stderr>

Set and retrieve the current filehandle to be used for printing
error messages. Default is to use STDERR.

=cut

sub stderr {
  my $self = shift;
  if (@_) {
    my $hdl = shift;
    $self->{STDERR} = $hdl;
  }
  return $self->{STDERR};
}


=item B<stdout>

Set and retrieve the current filehandle to be used for printing
normal DRAMA messages. Default is to use STDOUT. This can be
a tied filehandle (eg one generated by ORAC::Print).

=cut

sub stdout {
  my $self = shift;
  if (@_) {
    my $hdl = shift;
    $self->{STDOUT} = $hdl;
  }
  return $self->{STDOUT};
}

=item B<paramrep>

Set and retrieve the code reference that will be executed if
the parameter system needs to ask for a parameter.

Not supported under DRAMA since there is no facility for triggering
a remote parameter request if the required parameter is missing.

=cut

sub paramrep {
  return;
}

=back

=head2 General Methods

=over 4

=item B<init>

Initialises the DRAMA messaging system. This routine should always be
called before attempting to talk to DRAMA tasks and has no effect if the
message system has already been enabled.

  $status = $drama->init();

The DRAMA system will be inintialised using a task name basesd on the
process ID. No arguments are required. Note that the Tk event loop
facility in DRAMA is not enabled since currently ORAC-DR only supports
synchronous DRAMA calls.

Returns ORAC__OK on successfull initialisation.

=cut

sub init {
  my $self = shift;
  return if $self->running;
  my $name = "oracdr_$$";

  # Buffer sizes
  $DRAMA::BUFSIZE = 4_000_000;

  # Override the space for receiving parameters
  # This limits replies to 80kB
  $DRAMA::REPLYBYTES   = 150000;
  $DRAMA::MAXREPLIES   = 4;

  DPerlInit( $name );

  $self->running(1);
  return ORAC__OK;
}


=back

=head1 CLASS METHODS

=over 4

=item B<require_uniqid>

Returns false, indicating that the DRAMA "engine" identifiers must
not be modified since the remote task controls its name in the message
system.

=cut

sub require_uniqid {
  return 0;
}

=back

=head1 REQUIREMENTS

This module requires the C<DRAMA> module.

=head1 SEE ALSO

L<ORAC::Msg::Control::ADAM>, L<DRAMA>

=head1 REVISION

$Id$

=head1 AUTHORS

Tim Jenness (t.jenness@jach.hawaii.edu)
and Frossie Economou (frossie@jach.hawaii.edu)

=head1 COPYRIGHT

Copyright (C) 2005 Particle Physics and Astronomy Research
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
