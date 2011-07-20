#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Test::Mock::Simple' );
}

diag( "Testing Test::Mock::Simple $Test::Mock::Simple::VERSION, Perl $], $^X" );
