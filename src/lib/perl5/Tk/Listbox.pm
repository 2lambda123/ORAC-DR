# Converted from listbox.tcl --
#
# This file defines the default bindings for Tk listbox widgets.
#
# @(#) listbox.tcl 1.7 94/12/17 16:05:18
#
# Copyright (c) 1994 The Regents of the University of California.
# Copyright (c) 1994 Sun Microsystems, Inc.
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.

# Modifications from standard Listbox.pm
# --------------------------------------
# 27-JAN-2001 Alasdair Allan
#    Modified for local use by adding tied scalar and arrays
#    Implemented TIESCALAR, TIEARRAY, FETCH, FETCHSIZE, STORE, CLEAR & EXTEND
# 31-JAN-2001 Alasdair Allan
#    Made changes suggested by Tim Jenness
# 03-FEB-2001 Alasdair Allan
#    Modified STORE for tied scalars to clear and select elements
# 06-FEB-2001 Alasdair Allan
#    Added POD documentation for tied listbox
# 13-FEB-2001 Alasdair Allan
#    Implemented EXISTS, DELETE, PUSH, POP, SHIFT & UNSHIFT for tied arrays
# 14-FEB-2001 Alasdair Allan
#    Implemented SPLICE for tied arrays, all tied functionality in place
# 16-FEB-2001 Alasdair Allan
#    Tweak to STORE interface for tied scalars
# 23-FEB-2001 Alasdair Allan
#    Added flag to FETCH for tied scalars, modified to return hashes
# 24-FEB-2001 Alasdair Allan
#    Updated Pod documentation
#

package Tk::Listbox;

use vars qw($VERSION);
$VERSION = '3.031';

use Tk qw(Ev $XS_VERSION);
use Tk::Clipboard ();
use AutoLoader;

use base  qw(Tk::Clipboard Tk::Widget);

Construct Tk::Widget 'Listbox';

bootstrap Tk::Listbox;

sub Tk_cmd { \&Tk::listbox }

Tk::Methods('activate','bbox','curselection','delete','get','index',
            'insert','nearest','scan','see','selection','size',
            'xview','yview');

use Tk::Submethods ( 'selection' => [qw(anchor clear includes set)],
                     'scan'      => [qw(mark dragto)],
                     'xview'     => [qw(moveto scroll)],
                     'yview'     => [qw(moveto scroll)],
                     );

*Getselected = \&getSelected;

sub clipEvents
{
 return qw[Copy];
}

sub BalloonInfo
{
 my ($listbox,$balloon,$X,$Y,@opt) = @_;
 my $e = $listbox->XEvent;
 my $index = $listbox->index('@' . $e->x . ',' . $e->y);
 foreach my $opt (@opt)
  {
   my $info = $balloon->GetOption($opt,$listbox);
   if ($opt =~ /^-(statusmsg|balloonmsg)$/ && UNIVERSAL::isa($info,'ARRAY'))
    {
     $balloon->Subclient($index);
     if (defined $info->[$index])
      {
       return $info->[$index];
      }
     return '';
    }
   return $info;
  }
}

sub ClassInit
{
 my ($class,$mw) = @_;
 $class->SUPER::ClassInit($mw);
 # Standard Motif bindings:
 $mw->bind($class,'<1>',['BeginSelect',Ev('index',Ev('@'))]);
 $mw->bind($class,'<B1-Motion>',['Motion',Ev('index',Ev('@'))]);
 $mw->bind($class,'<ButtonRelease-1>','ButtonRelease_1');
 ;
 $mw->bind($class,'<Shift-1>',['BeginExtend',Ev('index',Ev('@'))]);
 $mw->bind($class,'<Control-1>',['BeginToggle',Ev('index',Ev('@'))]);

 $mw->bind($class,'<B1-Leave>',['AutoScan',Ev('x'),Ev('y')]);
 $mw->bind($class,'<B1-Enter>','CancelRepeat');
 $mw->bind($class,'<Up>',['UpDown',-1]);
 $mw->bind($class,'<Shift-Up>',['ExtendUpDown',-1]);
 $mw->bind($class,'<Down>',['UpDown',1]);
 $mw->bind($class,'<Shift-Down>',['ExtendUpDown',1]);

 $mw->XscrollBind($class);
 $mw->PriorNextBind($class);

 $mw->bind($class,'<Control-Home>','Cntrl_Home');
 ;
 $mw->bind($class,'<Shift-Control-Home>',['DataExtend',0]);
 $mw->bind($class,'<Control-End>','Cntrl_End');
 ;
 $mw->bind($class,'<Shift-Control-End>',['DataExtend','end']);
 # $class->clipboardOperations($mw,'Copy');
 $mw->bind($class,'<space>',['BeginSelect',Ev('index','active')]);
 $mw->bind($class,'<Select>',['BeginSelect',Ev('index','active')]);
 $mw->bind($class,'<Control-Shift-space>',['BeginExtend',Ev('index','active')]);
 $mw->bind($class,'<Shift-Select>',['BeginExtend',Ev('index','active')]);
 $mw->bind($class,'<Escape>','Cancel');
 $mw->bind($class,'<Control-slash>','SelectAll');
 $mw->bind($class,'<Control-backslash>','Cntrl_backslash');
 ;
 # Additional Tk bindings that aren't part of the Motif look and feel:
 $mw->bind($class,'<2>',['scan','mark',Ev('x'),Ev('y')]);
 $mw->bind($class,'<B2-Motion>',['scan','dragto',Ev('x'),Ev('y')]);
 return $class;
}

=head1 TIED INTERFACE

The Tk::Listbox widget can also be tied to a scalar or array variable, with
different behaviour depending on the variable type, with the following
tie commands:

   use Tk;

   my ( @array, $scalar, $other );
   my %options = ( ReturnType => "index" );

   my $MW = MainWindow->new();
   my $lbox = $MW->Listbox()->pack();

   my @list = ( "a", "b", "c", "d", "e", "f" );
   $lbox->insert('end', @list );

   tie @array, "Tk::Listbox", $lbox
   tie $scalar, "Tk::Listbox", $lbox;
   tie $other, "Tk::Listbox", $lbox, %options;

currently only one modifier is implemented, a 3 way flag for tied scalars
"ReturnType" which can have values "element", "index" or "both". The default
is "element".

=over 4

=item Tied Arrays

If you tie an array to the Listbox you can manipulate the items currently
contained by the box in the same manner as a normal array, e.g.

    print @array;
    push(@array, @list);
    my $popped = pop(@array);
    my $shifted = shift(@array);
    unshift(@array, @list);
    delete $array[$index];
    print $string if exists $array[$i];
    @array = ();
    splice @array, $offset, $length, @list

The delete function is implemented slightly differently from the standard
array implementation. Instead of setting the element at that index to undef
it instead physically removes it from the Listbox. This has the effect of
changing the array indices, so for instance if you had a list on non-continuous
indices you wish to remove from the Listbox you should reverse sort the list
and then apply the delete function, e.g.

     my @list = ( 1, 2, 4, 12, 20 );
     my @remove = reverse sort { $a <=> $b } @list;
     delete @array[@remove];

would safely remove indices 20, 12, 4, 2 and 1 from the Listbox without
problems. It should also be noted that a similar warning applies to the
splice function (which would normally be used in this context to perform
the same job).

=cut

sub TIEARRAY {
  my ( $class, $obj, %options ) = @_;
  return bless {
            OBJECT => \$obj,
            OPTION => \%options }, $class;
}

=item Tied Scalars

Unlike tied arrays, if you tie a scalar to the Listbox you can retrieve the
currently selected elements in the box as an array referenced by the scalar,
for instance

    my @list = ( "a", "b", "c", "d", "e", "f" );
    $lbox->insert('end', sort @list );
    $lbox->selectionSet(1);

inserts @list as elements in an already existing listbox and selects the
element at index 1, which is "b". If we then

     print @$selected;

this will return the currently selected elements, in this case "b".

However, if the "ReturnType" arguement is passed when tying the Listbox to the
scalar with value "index" then the indices of the selected elements will be
returned instead of the elements themselves, ie in this case "1". This can be
useful when manipulating both contents and selected elements in the Listbox at
the same time.

Importantly, if a value "both" is given the scalar will not be tied to an
array, but instead to a hash, with keys being the indices and values being
the elements at those indices

You can also manipulate the selected items using the scalar. Equating the
scalar to an array reference will select any elements that match elements
in the Listbox, non-matching array items are ignored, e.g.

    my @list = ( "a", "b", "c", "d", "e", "f" );
    $lbox->insert('end', sort @list );
    $lbox->selectionSet(1);

would insert the array @list into an already existing Listbox and select
element at index 1, i.e. "b"

    @array = ( "a", "b", "f" );
    $selected = \@array;

would select elements "a", "b" and "f" in the Listbox.

Again, if the "index" we indicate we want to use indices in the options hash
then the indices are use instead of elements, e.g.

    @array = ( 0, 1, 5 );
    $selected = \@array;

would have the same effect, selecting elements "a", "b" and "f" if the
$selected variable was tied with %options = ( ReturnType => "index" ).

If we are returning "both", i.e. the tied scalar points to a hash, both key and
value must match, e.g.

    %hash = ( 0 => "a", 1 => "b", 5 => "f" );
    $selected = \%hash;

would have the same effect as the previous examples.

It should be noted that, despite being a reference to an array (or possibly a has), you still can not copy the tied variable without it being untied, instead
you must pass a reference to the tied scalar between subroutines.

=back

=cut

sub TIESCALAR {
  my ( $class, $obj, %options ) = @_;
  return bless {
            OBJECT => \$obj,
            OPTION => \%options }, $class;
}

# FETCH
# -----
# Return either the full contents or only the selected items in the
# box depending on whether we tied it to an array or scalar respectively
sub FETCH {
  my $class = shift;

  my $self = ${$class->{OBJECT}};
  my %options = %{$class->{OPTION}} if defined $class->{OPTION};;

  # Define the return variable
  my $result;

  # Check whether we are have a tied array or scalar quantity
  if ( @_ ) {
     my $i = shift;
     # The Tk:: Listbox has been tied to an array, we are returning
     # an array list of the current items in the Listbox
     $result = $self->get($i);
  } else {
     # The Tk::Listbox has been tied to a scalar, we are returning a
     # reference to an array or hash containing the currently selected items
     my ( @array, %hash );

     if ( defined $options{ReturnType} ) {

        # THREE-WAY SWITCH
        if ( $options{ReturnType} eq "index" ) {
           $result = [$self->curselection];
        } elsif ( $options{ReturnType} eq "element" ) {
           foreach my $selection ( $self->curselection ) {
              push(@array,$self->get($selection)); }
           $result = \@array;
        } elsif ( $options{ReturnType} eq "both" ) {
           foreach my $selection ( $self->curselection ) {
              %hash = ( %hash, $selection => $self->get($selection)); }
           $result = \%hash;
        }
     } else {
        # return elements (default)
        foreach my $selection ( $self->curselection ) {
           push(@array,$self->get($selection)); }
        $result = \@array;
     }
  }
  return $result;
}

# FETCHSIZE
# ---------
# Return the number of elements in the Listbox when tied to an array
sub FETCHSIZE {
  my $class = shift;
  return ${$class->{OBJECT}}->size();
}

# STORE
# -----
# If tied to an array we will modify the Listbox contents, while if tied
# to a scalar we will select and clear elements.
sub STORE {

  if ( scalar(@_) == 2 ) {
     # we have a tied scalar
     my ( $class, $selected ) = @_;
     my $self = ${$class->{OBJECT}};
     my %options = %{$class->{OPTION}} if defined $class->{OPTION};;

     # clear currently selected elements
     $self->selectionClear(0,'end');

     # set selected elements
     if ( defined $options{ReturnType} ) {

        # THREE-WAY SWITCH
        if ( $options{ReturnType} eq "index" ) {
           for ( my $i=0; $i < scalar(@$selected) ; $i++ ) {
              for ( my $j=0; $j < $self->size() ; $j++ ) {
                  if( $j == $$selected[$i] ) {
                     $self->selectionSet($j); last; }
              }
           }
        } elsif ( $options{ReturnType} eq "element" ) {
           for ( my $k=0; $k < scalar(@$selected) ; $k++ ) {
              for ( my $l=0; $l < $self->size() ; $l++ ) {
                 if( $self->get($l) eq $$selected[$k] ) {
                    $self->selectionSet($l); last; }
              }
           }
        } elsif ( $options{ReturnType} eq "both" ) {
           foreach my $key ( keys %$selected ) {
              $self->selectionSet($key)
                      if $$selected{$key} eq $self->get($key);
           }
        }
     } else {
        # return elements (default)
        for ( my $k=0; $k < scalar(@$selected) ; $k++ ) {
           for ( my $l=0; $l < $self->size() ; $l++ ) {
              if( $self->get($l) eq $$selected[$k] ) {
                 $self->selectionSet($l); last; }
           }
        }
     }

  } else {
     # we have a tied array
     my ( $class, $index, $value ) = @_;
     my $self = ${$class->{OBJECT}};

     # check size of current contents list
     my $sizeof = $self->size();

     if ( $index <= $sizeof ) {
        # Change a current listbox entry
        $self->delete($index);
        $self->insert($index, $value);
     } else {
        # Add a new value
        if ( defined $index ) {
           $self->insert($index, $value);
        } else {
           $self->insert("end", $value);
        }
     }
   }
}

# CLEAR
# -----
# Empty the Listbox of contents if tied to an array
sub CLEAR {
  my $class = shift;
  ${$class->{OBJECT}}->delete(0, 'end');
}

# EXTEND
# ------
# Do nothing and be happy about it
sub EXTEND { }

# PUSH
# ----
# Append elements onto the Listbox contents
sub PUSH {
  my ( $class, @list ) = @_;
  ${$class->{OBJECT}}->insert('end', @list);
}

# POP
# ---
# Remove last element of the array and return it
sub POP {
   my $class = shift;

   my $value = ${$class->{OBJECT}}->get('end');
   ${$class->{OBJECT}}->delete('end');
   return $value;
}

# SHIFT
# -----
# Removes the first element and returns it
sub SHIFT {
   my $class = shift;

   my $value = ${$class->{OBJECT}}->get(0);
   ${$class->{OBJECT}}->delete(0);
   return $value
}

# UNSHIFT
# -------
# Insert elements at the beginning of the Listbox
sub UNSHIFT {
   my ( $class, @list ) = @_;
   ${$class->{OBJECT}}->insert(0, @list);
}

# DELETE
# ------
# Delete element at specified index
sub DELETE {
   my ( $class, @list ) = @_;

   my $value = ${$class->{OBJECT}}->get(@list);
   ${$class->{OBJECT}}->delete(@list);
   return $value;
}

# EXISTS
# ------
# Returns true if the index exist, and undef if not
sub EXISTS {
   my ( $class, $index ) = @_;
   return undef unless ${$class->{OBJECT}}->get($index);
}

# SPLICE
# ------
# Performs equivalent of splice on the listbox contents
sub SPLICE {
   my $class = shift;

   my $self = ${$class->{OBJECT}};

   # check for arguments
   my @elements;
   if ( scalar(@_) == 0 ) {
      # none
      @elements = $self->get(0,'end');
      $self->delete(0,'end');
      return wantarray ? @elements : $elements[scalar(@elements)-1];;

   } elsif ( scalar(@_) == 1 ) {
      # $offset
      my ( $offset ) = @_;
      if ( $offset < 0 ) {
         my $start = $self->size() + $offset;
         if ( $start > 0 ) {
            @elements = $self->get($start,'end');
            $self->delete($start,'end');
            return wantarray ? @elements : $elements[scalar(@elements)-1];
         } else {
            return undef;
         }
      } else {
         @elements = $self->get($offset,'end');
         $self->delete($offset,'end');
         return wantarray ? @elements : $elements[scalar(@elements)-1];
      }

   } elsif ( scalar(@_) == 2 ) {
      # $offset and $length
      my ( $offset, $length ) = @_;
      if ( $offset < 0 ) {
         my $start = $self->size() + $offset;
         my $end = $self->size() + $offset + $length - 1;
         if ( $start > 0 ) {
            @elements = $self->get($start,$end);
            $self->delete($start,$end);
            return wantarray ? @elements : $elements[scalar(@elements)-1];
         } else {
            return undef;
         }
      } else {
         @elements = $self->get($offset,$offset+$length-1);
         $self->delete($offset,$offset+$length-1);
         return wantarray ? @elements : $elements[scalar(@elements)-1];
      }

   } else {
      # $offset, $length and @list
      my ( $offset, $length, @list ) = @_;
      if ( $offset < 0 ) {
         my $start = $self->size() + $offset;
         my $end = $self->size() + $offset + $length - 1;
         if ( $start > 0 ) {
            @elements = $self->get($start,$end);
            $self->delete($start,$end);
            $self->insert($start,@list);
            return wantarray ? @elements : $elements[scalar(@elements)-1];
         } else {
            return undef;
         }
      } else {
         @elements = $self->get($offset,$offset+$length-1);
         $self->delete($offset,$offset+$length-1);
         $self->insert($offset,@list);
         return wantarray ? @elements : $elements[scalar(@elements)-1];
      }
   }
}

# ----

1;
__END__

#
# Bind --
# This procedure is invoked the first time the mouse enters a listbox
# widget or a listbox widget receives the input focus. It creates
# all of the class bindings for listboxes.
#
# Arguments:
# event - Indicates which event caused the procedure to be invoked
# (Enter or FocusIn). It is used so that we can carry out
# the functions of that event in addition to setting up
# bindings.

sub xyIndex
{
 my $w = shift;
 my $Ev = $w->XEvent;
 return $w->index($Ev->xy);
}

sub ButtonRelease_1
{
 my $w = shift;
 my $Ev = $w->XEvent;
 $w->CancelRepeat;
 $w->activate($Ev->xy);
}


sub Cntrl_Home
{
 my $w = shift;
 my $Ev = $w->XEvent;
 $w->activate(0);
 $w->see(0);
 $w->selectionClear(0,'end');
 $w->selectionSet(0)
}


sub Cntrl_End
{
 my $w = shift;
 my $Ev = $w->XEvent;
 $w->activate('end');
 $w->see('end');
 $w->selectionClear(0,'end');
 $w->selectionSet('end')
}


sub Cntrl_backslash
{
 my $w = shift;
 my $Ev = $w->XEvent;
 if ($w->cget('-selectmode') ne 'browse')
 {
 $w->selectionClear(0,'end');
 }
}

# BeginSelect --
#
# This procedure is typically invoked on button-1 presses. It begins
# the process of making a selection in the listbox. Its exact behavior
# depends on the selection mode currently in effect for the listbox;
# see the Motif documentation for details.
#
# Arguments:
# w - The listbox widget.
# el - The element for the selection operation (typically the
# one under the pointer). Must be in numerical form.
sub BeginSelect
{
 my $w = shift;
 my $el = shift;
 if ($w->cget('-selectmode') eq 'multiple')
  {
   if ($w->selectionIncludes($el))
    {
     $w->selectionClear($el)
    }
   else
    {
     $w->selectionSet($el)
    }
  }
 else
  {
   $w->selectionClear(0,'end');
   $w->selectionSet($el);
   $w->selectionAnchor($el);
   @Selection = ();
   $Prev = $el
  }
 $w->focus if ($w->cget('-takefocus'));
}
# Motion --
#
# This procedure is called to process mouse motion events while
# button 1 is down. It may move or extend the selection, depending
# on the listbox's selection mode.
#
# Arguments:
# w - The listbox widget.
# el - The element under the pointer (must be a number).
sub Motion
{
 my $w = shift;
 my $el = shift;
 if (defined($Prev) && $el == $Prev)
  {
   return;
  }
 $anchor = $w->index('anchor');
 my $mode = $w->cget('-selectmode');
 if ($mode eq 'browse')
  {
   $w->selectionClear(0,'end');
   $w->selectionSet($el);
   $Prev = $el;
  }
 elsif ($mode eq 'extended')
  {
   $i = $Prev;
   if ($w->selectionIncludes('anchor'))
    {
     $w->selectionClear($i,$el);
     $w->selectionSet('anchor',$el)
    }
   else
    {
     $w->selectionClear($i,$el);
     $w->selectionClear('anchor',$el)
    }
   while ($i < $el && $i < $anchor)
    {
     if (Tk::lsearch(\@Selection,$i) >= 0)
      {
       $w->selectionSet($i)
      }
     $i += 1
    }
   while ($i > $el && $i > $anchor)
    {
     if (Tk::lsearch(\@Selection,$i) >= 0)
      {
       $w->selectionSet($i)
      }
     $i += -1
    }
   $Prev = $el
  }
}
# BeginExtend --
#
# This procedure is typically invoked on shift-button-1 presses. It
# begins the process of extending a selection in the listbox. Its
# exact behavior depends on the selection mode currently in effect
# for the listbox; see the Motif documentation for details.
#
# Arguments:
# w - The listbox widget.
# el - The element for the selection operation (typically the
# one under the pointer). Must be in numerical form.
sub BeginExtend
{
 my $w = shift;
 my $el = shift;
 if ($w->cget('-selectmode') eq 'extended' && $w->selectionIncludes('anchor'))
  {
   $w->Motion($el)
  }
}
# BeginToggle --
#
# This procedure is typically invoked on control-button-1 presses. It
# begins the process of toggling a selection in the listbox. Its
# exact behavior depends on the selection mode currently in effect
# for the listbox; see the Motif documentation for details.
#
# Arguments:
# w - The listbox widget.
# el - The element for the selection operation (typically the
# one under the pointer). Must be in numerical form.
sub BeginToggle
{
 my $w = shift;
 my $el = shift;
 if ($w->cget('-selectmode') eq 'extended')
  {
   @Selection = $w->curselection();
   $Prev = $el;
   $w->selectionAnchor($el);
   if ($w->selectionIncludes($el))
    {
     $w->selectionClear($el)
    }
   else
    {
     $w->selectionSet($el)
    }
  }
}
# AutoScan --
# This procedure is invoked when the mouse leaves an entry window
# with button 1 down. It scrolls the window up, down, left, or
# right, depending on where the mouse left the window, and reschedules
# itself as an "after" command so that the window continues to scroll until
# the mouse moves back into the window or the mouse button is released.
#
# Arguments:
# w - The entry window.
# x - The x-coordinate of the mouse when it left the window.
# y - The y-coordinate of the mouse when it left the window.
sub AutoScan
{
 my $w = shift;
 my $x = shift;
 my $y = shift;
 if ($y >= $w->height)
  {
   $w->yview('scroll',1,'units')
  }
 elsif ($y < 0)
  {
   $w->yview('scroll',-1,'units')
  }
 elsif ($x >= $w->width)
  {
   $w->xview('scroll',2,'units')
  }
 elsif ($x < 0)
  {
   $w->xview('scroll',-2,'units')
  }
 else
  {
   return;
  }
 $w->Motion($w->index("@" . $x . ',' . $y));
 $w->RepeatId($w->after(50,'AutoScan',$w,$x,$y));
}
# UpDown --
#
# Moves the location cursor (active element) up or down by one element,
# and changes the selection if we're in browse or extended selection
# mode.
#
# Arguments:
# w - The listbox widget.
# amount - +1 to move down one item, -1 to move back one item.
sub UpDown
{
 my $w = shift;
 my $amount = shift;
 $w->activate($w->index('active')+$amount);
 $w->see('active');
 $LNet__0 = $w->cget('-selectmode');
 if ($LNet__0 eq 'browse')
  {
   $w->selectionClear(0,'end');
   $w->selectionSet('active')
  }
 elsif ($LNet__0 eq 'extended')
  {
   $w->selectionClear(0,'end');
   $w->selectionSet('active');
   $w->selectionAnchor('active');
   $Prev = $w->index('active');
   @Selection = ();
  }
}
# ExtendUpDown --
#
# Does nothing unless we're in extended selection mode; in this
# case it moves the location cursor (active element) up or down by
# one element, and extends the selection to that point.
#
# Arguments:
# w - The listbox widget.
# amount - +1 to move down one item, -1 to move back one item.
sub ExtendUpDown
{
 my $w = shift;
 my $amount = shift;
 if ($w->cget('-selectmode') ne 'extended')
  {
   return;
  }
 $w->activate($w->index('active')+$amount);
 $w->see('active');
 $w->Motion($w->index('active'))
}
# DataExtend
#
# This procedure is called for key-presses such as Shift-KEndData.
# If the selection mode isn't multiple or extend then it does nothing.
# Otherwise it moves the active element to el and, if we're in
# extended mode, extends the selection to that point.
#
# Arguments:
# w - The listbox widget.
# el - An integer element number.
sub DataExtend
{
 my $w = shift;
 my $el = shift;
 $mode = $w->cget('-selectmode');
 if ($mode eq 'extended')
  {
   $w->activate($el);
   $w->see($el);
   if ($w->selectionIncludes('anchor'))
    {
     $w->Motion($el)
    }
  }
 elsif ($mode eq 'multiple')
  {
   $w->activate($el);
   $w->see($el)
  }
}
# Cancel
#
# This procedure is invoked to cancel an extended selection in
# progress. If there is an extended selection in progress, it
# restores all of the items between the active one and the anchor
# to their previous selection state.
#
# Arguments:
# w - The listbox widget.
sub Cancel
{
 my $w = shift;
 if ($w->cget('-selectmode') ne 'extended' || !defined $Prev)
  {
   return;
  }
 $first = $w->index('anchor');
 $last = $Prev;
 if ($first > $last)
  {
   $tmp = $first;
   $first = $last;
   $last = $tmp
  }
 $w->selectionClear($first,$last);
 while ($first <= $last)
  {
   if (Tk::lsearch(\@Selection,$first) >= 0)
    {
     $w->selectionSet($first)
    }
   $first += 1
  }
}
# SelectAll
#
# This procedure is invoked to handle the "select all" operation.
# For single and browse mode, it just selects the active element.
# Otherwise it selects everything in the widget.
#
# Arguments:
# w - The listbox widget.
sub SelectAll
{
 my $w = shift;
 my $mode = $w->cget('-selectmode');
 if ($mode eq 'single' || $mode eq 'browse')
  {
   $w->selectionClear(0,'end');
   $w->selectionSet('active')
  }
 else
  {
   $w->selectionSet(0,'end')
  }
}

sub SetList
{
 my $w = shift;
 $w->delete(0,'end');
 $w->insert('end',@_);
}

sub deleteSelected
{
 my $w = shift;
 my $i;
 foreach $i (reverse $w->curselection)
  {
   $w->delete($i);
  }
}

sub clipboardPaste
{
 my $w = shift;
 my $index = $w->index('active') || $w->index($w->XEvent->xy);
 my $str;
 eval {local $SIG{__DIE__}; $str = $w->clipboardGet };
 return if $@;
 foreach (split("\n",$str))
  {
   $w->insert($index++,$_);
  }
}

sub getSelected
{
 my ($w) = @_;
 my $i;
 my (@result) = ();
 foreach $i ($w->curselection)
  {
   push(@result,$w->get($i));
  }
 return (wantarray) ? @result : $result[0];
}



1;
__END__
