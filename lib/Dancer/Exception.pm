package Dancer::Exception;

use strict;
use warnings;
use Carp;

use base qw(Exporter);

my @exceptions = qw(E_GENERIC E_INTERNAL E_HALTED E_HOOK E_REQUEST E_SESSION);
our @EXPORT_OK = (@exceptions, qw(raise list_exceptions is_dancer_exception register_custom_exception));
our %value_to_custom_name;
our %custom_name_to_value;
our %EXPORT_TAGS = ( exceptions => [ @exceptions],
                     internal_exceptions => [ @exceptions],
                     custom_exceptions => [],
                     utils => => [ qw(raise list_exceptions is_dancer_exception register_custom_exception) ],
                     all => \@EXPORT_OK,
                   );

use overload '""' => sub { $_[0]->message  };
use overload '0+' => sub { $_[0]->value };

use overload '+' => sub {
    ref $_[1] eq __PACKAGE__
      and return $_[0]->value + $_[1]->value;
    return $_[0]->value + $_[1];
};

use overload '-' => sub {
    ref $_[1] eq __PACKAGE__
      and return $_[0]->value - $_[1]->value;
    return $_[0]->value - $_[1];
};

use overload '*' => sub {
    ref $_[1] eq __PACKAGE__
      and return $_[0]->value * $_[1]->value;
    return $_[0]->value * $_[1];
};

use overload '/' => sub {
    ref $_[1] eq __PACKAGE__
      and return $_[0]->value / $_[1]->value;
    return $_[0]->value / $_[1];
};

use overload '.' => sub {
    ref $_[1] eq __PACKAGE__
      and return $_[0]->message . $_[1]->message;
    return $_[0]->message . $_[1];
};

use overload '<=>' => sub {
    ref $_[1] eq __PACKAGE__
      and return $_[0]->value <=> $_[1]->value;
    return $_[0]->value <=> $_[1];
};

use overload 'cmp' => sub {
    ref $_[1] eq __PACKAGE__
      and return $_[0]->message cmp $_[1]->message;
    return $_[0]->message cmp $_[1];
};

use overload '&' => sub {
    ref $_[1] eq __PACKAGE__
      and return $_[0]->message & $_[1]->value;
    return $_[0]->value & $_[1];
};

use overload '|' => sub {
    ref $_[1] eq __PACKAGE__
      and return $_[0]->message | $_[1]->value;
    return $_[0]->value | $_[1];
};

=head1 SYNOPSIS

  use Dancer::Exception qw(:all);

  # raise an exception
  raise E_HALTED;

  # raise an exception with a message
  raise E_GENERIC, "Oops, I broke my leg";

  # get a list of possible exceptions
  my @exception_names = list_exceptions;

  # catch an exception
  eval { ... };
  my $exception = $@;
  if ( is_dancer_exception($exception) ) {
    if ($exception->value == ( E_HALTED | E_FOO ) ) {
        # it's a halt and foo exception...
        my $message = $exception->message;
        # ...
    }
  } elsif ($exception) {
    # it's not a dancer exception (don't use $@ as it may have been reset)
  }

  # exceptions also support various overloading (see OVERLOADING below)
  eval { raise E_GENERIC, "plop"}
  my $e = $@;
  if ($e eq "plop") {
    # will be executed
  }
  if ($e & E_GENERIC) {
    # will be executed
  }

=head1 REAL LIFE EXAMPLE


=head1 DESCRIPTION

This is a lighweight exceptions module. The primary goal is to keep it light
and fast.

An exception is a blessed reference on ArrayRef, which contains an integer and
optionally a message. The integer is always a power of two, so that you can
test its value using the C<|> operator. A Dancer exception is always blessed as
C<'Dancer::Exception'>.

An exception is technically an object, but there is no inheritance mechanism.

The only methods you can call on an exception are C<value()> and C<message()>.

=head1 EXPORTS

to be able to use this module, you should use it with these options :

  # loads specific exceptions only. See list_exceptions for a list
  use Dancer::Exception qw(E_HALTED E_PLOP);

  # loads the utility functions
  use Dancer::Exception qw(raise list_exceptions is_dancer_exception register_custom_exception);

  # this does the same thing as above
  use Dancer::Exception qw(:utils);

  # loads all exception names, but not the utils
  use Dancer::Exception qw(:exceptions);

  # loads only the internal exception names
  use Dancer::Exception qw(:internal_exceptions);

  # loads only the custom exception names
  use Dancer::Exception qw(:custom_exceptions);

  # loads everything
  use Dancer::Exception qw(:all);

  # you can combine stuff. Here we only import raise and the exceptions
  use Dancer::Exception qw(raise :exceptions);

=head1 FUNCTIONS

=head2 raise

  raise E_HALTED;

Used to raise an exception. Takes in arguments:

=over

=item *

The exception value. It's an integer (must be a power of
2). You should give it an existing Dancer exception.

=item *

An optional argument, the exception message. It should be a string.

=back

=cut

# yes we use __PACKAGE__, it's not OO and inheritance proof, but if you'd pay
# attention, you'd have noticed that this module is *not* a class :)
sub raise { die bless [ @_ ], __PACKAGE__ }

=head2 list_exceptions

  my @exception_names = list_exceptions;
  my @exception_names = list_exceptions(type => 'internal');
  my @exception_names = list_exceptions(type => 'custom');

Returns a list of strings, the names of available exceptions.

Parameters are an optional list of key values. Accepted keys are for now only
C<type>, to restrict the list of exceptions on the type of the Dancer
exception. C<type> can be 'internal' or 'custom'.

=cut

sub list_exceptions {
    my %params = @_;
    ( $params{type} || '' ) eq 'internal'
      and return @exceptions;
    ( $params{type} || '' ) eq 'custom'
      and return keys %custom_name_to_value;
    return @exceptions, keys %custom_name_to_value;
}

=head2 is_dancer_exception

  # test if it's a Dancer exception
  my $value = is_dancer_exception($@);
  # test if it's a Dancer internal exception
  my $value = is_dancer_exception($@, type => 'internal');
  # test if it's a Dancer custom exception
  my $value = is_dancer_exception($@, type => 'custom');

This function tests if an exception is a Dancer exception, and if yes get its
value. If not, it returns 0;

First parameter is the exception to test. Other parameters are an optional list
of key values. Accepted keys are for now only C<type>, to restrict the test on
the type of the Dancer exception. C<type> can be 'internal' or 'custom'.

Returns the exception value (which is always true), or zero if the exception
was not a dancer exception (of the right type if specified).

=cut

sub is_dancer_exception {
    my ($exception, %params) = @_;
    ref $exception eq __PACKAGE__
      or return 0;
    my $value = $exception->value;
    @_ > 1
      or return $value;
    $params{type} eq 'internal' && $value < 2**16
      and return $value;
    $params{type} eq 'custom' && $value >= 2**16
      and return $value;
    return 0;
}

=head2 register_custom_exception

  register_custom_exception('E_FROBNICATOR');
  # now I can use this exception for raising
  raise E_FROBNICATOR;

=cut

sub register_custom_exception {
    my ($exception_name, %params) = @_;
    exists $value_to_custom_name{$exception_name}
      and croak "can't register '$exception_name' custom exception, it already exists";
    keys %value_to_custom_name < 16
      or croak "can't register '$exception_name' custom exception, all 16 custom slots are registered";
    my $value = 2**16;
    while($value_to_custom_name{$value}) { $value*=2; }
    $value_to_custom_name{$value} = $exception_name;
    $custom_name_to_value{$exception_name} = $value;

    my $pkg = __PACKAGE__;
    no strict 'refs';
    *{"$pkg\::$exception_name"} = sub { $value };

    push @EXPORT_OK, $exception_name;
    push @{$EXPORT_TAGS{custom_exceptions}}, $exception_name;
    $params{no_import}
      or $pkg->export_to_level(1, $pkg, $exception_name);

    return;
}

=head1 METHODS

The following methods can be called on an exception

=head2 value

Return or set the value of the exception. Warning, no check is done. Use
C<is_dancer_exception> before using this method if you are unsure.

With no argument, the exception value is returned.

If an argument is given, the exception value is set to this new value. It
should be a valid exception value (use C<list_exceptions> to get a list of
them). The new value is returned.

=cut

sub value {
    @_ > 1 and $_[0]->[0] = $_[1];
    return $_[0]->[0];
}

=head2 message

Return or set the message of the exception. Warning, no check is done. Use
C<is_dancer_exception> before using this method if you are unsure.

With no argument, the exception message is returned. If the exception has no
message defined, returns C<void> (empty list). That is different from the case
where the exception has an undefined message. In this case, C<undef> is
returned.

If an argument is given, the exception message is set to this new message. The
new message is returned.

=cut

sub message {
    @_ > 1 and $_[0]->[1] = $_[1];
    return $_[0]->[1];
}

=head1 OVERLOADING

Dancer exceptions overloads several operators, returning the exception values
or message depending on the case.

Basically, Dancer exceptions stringify to their message, and numerify to their
value.

Here is the list of overloaded operators : C<"">, C<0+>, C<+>, C<->, C<*>,
C</>, C<.>, C<< <=> >>, C<cmp>, C<&>, C<|>.

=head1 INTERNAL EXCEPTIONS

=head2 E_GENERIC

A generic purpose exception. Not used by internal code, so this exception can
be used by user code safely, without having to register a custom user exception.

=cut

sub E_GENERIC () { 2**0 }

=head2 E_INTERNAL

General internal exception, generated something bad happen, but can't be
related to anything specific.

=cut

sub E_INTERNAL () { 2**1 }

=head2 E_HALTED

Internal exception, generated when C<halt()> is called (see in L<Dancer> POD).

=cut

sub E_HALTED () { 2**2 }

=head2 E_HOOK

Internal exception, related to a Dancer hook. If an exception is raised in a
hook, the exception will also be a E_HOOK exception.

=cut

sub E_HOOK () { 2**3 }

=head2 E_REQUEST

Internal exception, related to a Dancer request.

=cut

sub E_REQUEST () { 2**4 }

=head2 E_SESSION

Internal exception, related to Dancer sessions.

=cut

sub E_SESSION () { 2**5 }

=head1 CUSTOM EXCEPTIONS

In addition to internal (and the generic one) exception, users have the ability
to register more Dancer exceptions for their need. To do that, see
C<register_custom_exception>.

=cut

1;
