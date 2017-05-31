package Zonemaster::Engine::Test::Example;

use version; our $VERSION = version->declare("v1.0.2");

###
### This test module is meant to serve as an example when writing proper ones.
###

use strict;
use warnings;

use 5.014002;

use Zonemaster;
use Zonemaster::Util;

###
### Entry points
###

sub all {
    my ( $class, $zone ) = @_;
    my @results;

    push @results, $class->placeholder if Zonemaster->config->should_run( 'placeholder' );

    return @results;
}

###
### Metadata Exposure
###

sub metadata {
    my ( $class ) = @_;

    return { placeholder => [qw( EXAMPLE_TAG )] };
}

sub version {
    return "$Zonemaster::Engine::Test::Example::VERSION";
}

sub translation {
    return { EXAMPLE_TAG => 'This is an example tag.', };
}

sub policy {
    return { EXAMPLE_TAG => 'DEBUG', };
}

###
### Tests
###

sub placeholder {
    my ( $class, $zone ) = @_;
    my @results;

    push @results, info( EXAMPLE_TAG => { example_arg => 'example_value' } );

    return @results;
}

1;

=head1 NAME

Zonemaster::Engine::Test::Example - example module showing the expected structure of Zonemaster test modules

=head1 SYNOPSIS

    my @results = Zonemaster::Engine::Test::Example->all($zone);

=head1 METHODS

=over

=item all($zone)

Runs the default set of tests and returns a list of log entries made by the tests.

=item metadata()

Returns a reference to a hash, the keys of which are the names of all test methods in the module, and the corresponding values are references to
lists with all the tags that the method can use in log entries.

=item translation()

Returns a reference to a nested hash, where the outermost keys are language
codes, the keys below that are message tags and their values are translation
strings.

=item policy()

Returns a reference to a hash with the default policy for the module. The keys
are message tags, and the corresponding values are their default log levels.

=item version()

Returns a version string for the module.

=back

=head1 TESTS

=over

=item placeholder($zone)

Since this is an example module, this test does nothing except return a single log entry.

=back

=cut
