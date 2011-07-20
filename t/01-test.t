#! /usr/bin/perl
use strict;
use warnings;
use Test::More tests =>
  + 7 # test_01.
  + 7 # test_02.
  + 3 # test_03.
  + 5 # test_04.
  ;
use Test::Mock::Simple;

caller or __PACKAGE__->main(@ARGV);

sub main
{
  test_01(); # 7.
  test_02(); # 7.
  test_03(); # 3.
  test_04(); # 5.
}

# tests => 7.
sub test_01
{
  pass("[test_01]");
  my $mock = Test::Mock::Simple->new();
  isa_ok($mock, 'Test::Mock::Simple');
  my $x = 0;
  $mock->set(__PACKAGE__."#call_01" => sub {
    ++ $x;
    return "wrapped $x";
  });

  is( call_01(), "call_01", "call (before mock)");
  $mock->run(sub{
    pass("run");
    is( call_01(), "wrapped 1", "call (1st time)");
    is( call_01(), "wrapped 2", "call (2nd time)");
  });
  is( call_01(), "call_01", "call (leave mock)");
}

sub call_01
{
  return "call_01";
}

# tests => 7.
sub test_02
{
  pass("[test_02]");
  my $mock = Test::Mock::Simple->new();
  isa_ok($mock, 'Test::Mock::Simple');
  $mock->add(__PACKAGE__."#call_01" => sub {
    return "wrapped (add 1)";
  });
  $mock->add(__PACKAGE__."#call_01" => sub {
    return "wrapped (add 2)";
  });

  is( call_01(), "call_01", "call (before mock)");
  $mock->run(sub{
    pass("run");
    is( call_01(), "wrapped (add 1)", "call (1st time)");
    is( call_01(), "wrapped (add 2)", "call (2nd time)");
  });
  is( call_01(), "call_01", "call (leave mock)");
}

sub test_03
{
  pass("[test_03]");
  eval {
    my $mock = Test::Mock::Simple->new();
    $mock->add(__PACKAGE__."#call_01" => sub {});
    $mock->set(__PACKAGE__."#call_01" => sub {});
  };
  like( (my$err1=$@), qr/bad sequence/, 'no mix (add->set)');

  eval {
    my $mock = Test::Mock::Simple->new();
    $mock->set(__PACKAGE__."#call_01" => sub {});
    $mock->add(__PACKAGE__."#call_01" => sub {});
  };
  like( (my$err2=$@), qr/bad sequence/, 'no mix (set->add)');
}

sub test_04
{
  pass("[test_04]");
  our $call_01 = "VALUE";
  my $mock = Test::Mock::Simple->new();
  $mock->set(__PACKAGE__."#call_01" => sub { $call_01 });
  is($mock->run(sub{call_01()}), "VALUE", "SCALAR not hidden by glob");

  my $file = __FILE__;
  local(*call_01);
  open(*call_01, "<", $file) or die "open: $file: $!";
  my $size = -s $file;
  isnt($size, undef, "valid file size: [$size]");
  is(-s *call_01, $size, "-s *glob");
  is($mock->run(sub{-s *call_01}), $size, "IO not hidden by glob");
}

# -----------------------------------------------------------------------------
# End of File.
# -----------------------------------------------------------------------------
