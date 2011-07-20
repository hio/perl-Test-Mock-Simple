# -----------------------------------------------------------------------------
# Test::Mock::Simple
# -----------------------------------------------------------------------------
package Test::Mock::Simple;
use strict;
use warnings;
use Scalar::Util qw(weaken);

our $VERSION = '0.01';
$VERSION = eval $VERSION;

our $RE_MODNAME = qr/^[a-z_]\w*(?:\::[a-z_]\w*)*\z/i;
our $RE_SUBNAME = qr/^[a-z_]\w*\z/i;

1;

sub new
{
  my $pkg = shift;
  my $code = shift; # maybe(CODE)
  if( $code )
  {
    ref($code) eq 'CODE' or die "code is not CODE-ref";
  }

  my $this = bless {
    mode  => undef, # sequence/wrap
    mocks => [],
    code  => $code,
  }, $pkg;
  $this;
}

sub add
{
  my $this = shift;

  $this->{mode} ||= 'sequence';
  if( $this->{mode} ne 'sequence' )
  {
    die "bad sequence, added to $this->{mode} instance";
  }

  $this->__add_2(@_);
}

sub set
{
  my $this = shift;

  $this->{mode} ||= 'wrap';
  if( $this->{mode} ne 'wrap' )
  {
    die "bad sequence, set to $this->{mode} instance";
  }

  $this->__add_2(@_);
}

sub __add_2
{
  my $this = shift;

  if( !ref($_[0]) )
  {
    my $fullname = shift or die "no param: fullname";
    my $code     = shift or die "no param: code";
    my ($modname, $subname) = $fullname =~ /^(\S*)\s*(?:\::|\#)\s*(\S*)\z/s;
    defined($subname) or die "bad fullname: [$fullname]";
    $this->__add_3({
      module => $modname,
      sub    => $subname,
      code   => $code,
    });
  }else
  {
    $this->__add_3(@_);
  }
}

sub __add_3
{
  my $this = shift;
  my $opts = shift;

  my $modname = $opts->{module} or die "no param: module";
  my $subname = $opts->{sub}    or die "no param: sub";
  my $code    = $opts->{code}   or die "no param: code";

  $modname =~ $RE_MODNAME or die "bad modname: [$modname]";
  $subname =~ $RE_SUBNAME or die "bad subname: [$subname]";

  my $fullname = $modname . '::' . $subname;
  my $orig = $modname->can( $subname );
  if( !$orig )
  {
    #die "$fullname not exist";
  }

  my $item = {
    modname  => $modname,
    subname  => $subname,
    code     => $code,
    fullname => $fullname,
  };
  push(@{$this->{mocks}}, $item);
  $this;
}

sub run
{
  my $this = shift;
  my $code = shift || $this->{code};
  $code or die "no run code";
  ref($code) eq 'CODE' or die "code is not CODE-ref";
 
  # setup.
  my $state = $this->__setup();
  my $callback = $state->{callback};

  my $run = $state->{run};

  my $ret;
  if( wantarray() )
  {
    $ret = [$run->($code)];
  }else
  {
    $ret = scalar $run->($code);
  }

  if( $this->{mode} eq 'sequence' && $state->{calls} < @{$this->{mocks}} )
  {
    my $n = @{$this->{mocks}};
    my $n_mocks = $n . ($n == 1 ? ' mock' : ' mocks');
    die "$n_mocks defined, but called only ".__times_text($state->{calls});
  }

  wantarray() ? @$ret : $ret;
}

sub __setup
{
  my $this = shift;

  my $orig_subs = {};
  my $state_orig = {
    calls     => 0,
    orig_subs => $orig_subs,
    callback  => undef,
    eval_text => undef,
    run       => undef,
  };
  my $state = $state_orig;
  Scalar::Util::weaken($state);
  my $eval_text = '';
  $eval_text .= "no warnings qw(redefine);\n";
  foreach my $i (0..$#{$this->{mocks}})
  {
    my $item = $this->{mocks}[$i];
    my $fullname = $item->{fullname} or die "no param: fullname";
    $orig_subs->{$fullname} and next;

    my $modname = $item->{modname} or die "no param: modname";
    my $subname = $item->{subname} or die "no param: subname";
    my $orig = $modname->can( $subname );
    #$orig or die "$fullname not exist";
    $orig_subs->{$fullname} = $orig;

    $eval_text .= "__glob_restore(__glob_save(*$fullname),\\local(*$fullname));\n";
    $eval_text .= "*$fullname = sub{ \$this->__callback(\$state, '$fullname', \\\@_) };\n";
  }
  $eval_text .= "\$sub->();\n";

  $state->{eval_text} = $eval_text;

  #print "[eval]\n$state->{eval_text}\[/eval]\n";
  $state->{run}       = eval "sub{ my \$sub = shift; $eval_text }";
  $@ and die; # rethrow.

  $state;
}

sub __glob_save
{
  my $glob = shift;
  my $save = {};
  foreach my $key (qw(IO SCALAR ARRAY HASH CODE))
  {
    my $ref = *{$glob}{$key};
    if( $ref )
    {
      $save->{$key} = $ref;
    }
  }
  $save;
}

sub __glob_restore
{
  my $save = shift;
  my $glob = shift;
  foreach my $key (keys %$save)
  {
    $key eq 'CODE' and next;
    my $ref = $save->{$key};
    if( $ref )
    {
      *$glob = $ref;
    }
  }
}

sub __callback
{
  my $this  = shift;
  my $state = shift;
  my $fullname = shift;
  my $args     = shift;

  my $index = $state->{calls};
  ++ $state->{calls};

  my $mode = $this->{mode};
  $mode or die "no mode"; # assert.
  $mode =~ /^(?:sequence|wrap)\z/ or die "bad mode: [$mode]"; # assert.

  my $item;
  if( $mode eq 'sequence' )
  {
    $item = $this->{mocks}[$index] or die "too many calls (".__times_text($index+1).", this time is $fullname)";
  }else
  {
    foreach my $it (@{$this->{mocks}})
    {
      $it->{fullname} eq $fullname and $item = $it;
    }
    $item or die "$fullname not wrapped"; # assert.
  }

  if( $item->{fullname} ne $fullname )
  {
    my $nth = __nth_text($index+1);
    die "bad sequence, $nth is set $item->{fullname}, but called $fullname";
  }
  my $code = $item->{code};
  if( $code eq 'DEFAULT' )
  {
    my $orig = $state->{orig_subs}{$fullname} or die "no orig sub: $fullname";
    $orig->(@$args);
  }else
  {
    $code->(@$args);
  }
}

sub __times_text
{
  my $n = shift;
  $n == 1 ? "$n time" : "$n times";
}

sub __nth_text
{
  my $n = shift;
  my $x = $n % 10;
  my $y = $n % 100;
  if( $x == 1 )
  {
    $n . ($y == 11 ? "th" : "st");
  }elsif( $x == 2 )
  {
    $n . ($y == 12 ? "th" : "nd");
  }elsif( $x == 3 )
  {
    $n . "rd";
  }else
  {
    $n . "th";
  }
}

__END__

=head1 NAME

Test::Mock::Simple - small code mock.

=head1 SYNOPSIS

Perhaps a little code snippet.

  use Test::Mock::Simple;

  my $mock = Test::Mock::Simple->new();
  $mock->set( 'Module::sub' => sub{
    # mock implementation.
  });
  $mock->run(sub{
    # run code under mock environment.
  });

=head1 DESCRIPTION

Test::Mock::Simple provides another environment.
In this environment, some subroutines are reaplced.
This behavior is similar to C<< local(*sub) = \&new_code >>.

=head1 METHODS

=head2 new

 my $mock = Test::Mock::Simple->new();
 my $mock = Test::Mock::Simple->new($code);

=head2 set

 $mock->set( $fullsubname => $code );
 $mock->set( { module => $module, sub => $subname, code => $code } );

set mock code as wrap.

In run() code, you can call these mock codes in any order.

=head2 add

 $mock->add( $fullsubname => $code );
 $mock->add( { module => $module, sub => $subname, code => $code } );

add mock code as sequence.
could not mix with set().

In run() code, you should call these mock codes in same order with added.

=head2 run

 $mock->run($code);
 $mock->run(); # code is taken from constructor argument.

=head1 AUTHOR

YAMASHINA Hio, C<< <hio at hio.jp> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-test-mock-simple at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-Mock-Simple>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::Mock::Simple

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Test-Mock-Simple>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Test-Mock-Simple>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Test-Mock-Simple>

=item * Search CPAN

L<http://search.cpan.org/dist/Test-Mock-Simple>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2011 YAMASHINA Hio, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

# -----------------------------------------------------------------------------
# End of File.
# -----------------------------------------------------------------------------
