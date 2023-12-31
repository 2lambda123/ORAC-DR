package ORAC::Constants;

=head1 NAME

ORAC::Constants - Constants available to the ORAC system

=head1 SYNOPSIS

  use ORAC::Constants;
  use ORAC::Constants qw/ORAC__OK/;
  use ORAC::Constants qw/:status/;

=head1 DESCRIPTION

Provide access to ORAC constants, necessary to use this module if you wish
to return an ORAC__ABORT or ORAC__FATAL status using ORAC::Error.

=cut

use strict;
use warnings;

use NDF;

use vars qw/ $VERSION @ISA %EXPORT_TAGS @EXPORT_OK/;
$VERSION = '1.0';

require Exporter;

@ISA = qw/Exporter/;

@EXPORT_OK = qw/ORAC__OK ORAC__ERROR ORAC__BADENG
                ORAC__ABORT ORAC__FATAL ORAC__PARSE_ERROR
                ORAC__TERM VAL__BADD /;

%EXPORT_TAGS = (
                'status'=>[qw/ ORAC__OK ORAC__ERROR ORAC__BADENG
                               ORAC__ABORT ORAC__FATAL ORAC__PARSE_ERROR
                               ORAC__TERM ORAC__TERMERR ORAC__BADFRAME / ],
                'badvalues' => [qw/ VAL__BADD / ],
               );

Exporter::export_tags('status');
Exporter::export_ok_tags( 'badvalues' );

=head1 CONSTANTS

The following constants are available from this module:

=over 4

=item B<ORAC__OK>

This constant contains the definition of good ORAC status.

=cut

use constant ORAC__OK => 0;


=item B<ORAC__ERROR>

This constant contains the definition of bad ORAC status.

=cut

use constant ORAC__ERROR => -1;

# Did want to try implementing constants like this but
# is easier to use the constant module.
# *ORAC__OK = \0;

=item B<ORAC__BADENG>

An algorithm engine has returned with a status that indicates
that the engine is no longer valid. This can be used to
indicate that an engine has crashed and that a new one should be
launched.

=cut

use constant ORAC__BADENG => 2;

=item B<ORAC__ABORT>

This constant contains the definition a user aborted ORAC process

=cut

use constant ORAC__ABORT => -2;

=item B<ORAC__FATAL>

This constant contains the definition an ORAC process which has died fatally

=cut

use constant ORAC__FATAL => -3;

=item B<ORAC__PARSE_ERROR>

This constant contains the definition of an error in parsing a recipe.

=cut

use constant ORAC__PARSE_ERROR => -4;

=item B<ORAC__TERM>

This constant denotes that a recipe was terminated early, but without
error.

=cut

use constant ORAC__TERM => -5;

=item B<ORAC__TERMERR>

This constant denotes that a recipe was terminated early, but with
a handled error.

=cut

use constant ORAC__TERMERR => -6;

=item B<ORAC__BADFRAME>

This constant denotes that the recipe was completed with the
frame marked bad.

=cut

use constant ORAC__BADFRAME => -7;

=item B<VAL__BADD>

This constant denotes the numerical value for the special "bad" value
in NDF, for doubles.

=cut

use constant VAL__BADD => NDF::VAL__BADD;

=back

=head1 TAGS

Individual sets of constants can be imported by
including the module with tags. For example:

  use ORAC::Constants qw/:status/;

will import all constants associated with ORAC status checking.

The available tags are:

=over 4

=item :status

Constants associated with ORAC status checking: ORAC__OK and ORAC__ERROR.

=item :badvalues

Constants associated with bad values.

=back

=head1 USAGE

The constants can be used as if they are subroutines.
For example, if I want to print the value of ORAC__ERROR I can

  use ORAC::Constants;
  print ORAC__ERROR;

or

  use ORAC::Constants ();
  print ORAC::Constants::ORAC__ERROR;

=head1 SEE ALSO

L<constants>

=head1 AUTHOR

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt> and
Frossie Economou E<lt>frossie@jach.hawaii.eduE<gt>

=head1 REQUIREMENTS

The C<constants> package must be available. This is a standard
perl package.

=head1 COPYRIGHT

Copyright (C) 1998-2001 Particle Physics and Astronomy Research
Council. All Rights Reserved.

=cut



1;
