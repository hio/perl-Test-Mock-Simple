use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Test::Mock::Simple',
    AUTHOR              => 'YAMASHINA Hio <hio@hio.jp>',
    VERSION_FROM        => 'lib/Test/Mock/Simple.pm',
    ABSTRACT_FROM       => 'lib/Test/Mock/Simple.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Test-Mock-Simple-*' },
);
