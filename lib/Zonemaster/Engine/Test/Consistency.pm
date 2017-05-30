package Zonemaster::Test::Consistency;

use version; our $VERSION = version->declare("v1.1.1");

use strict;
use warnings;

use 5.014002;

use Zonemaster;
use Zonemaster::Util;
use Zonemaster::Test::Address;
use Zonemaster::Constants qw[:ip :soa];

use List::MoreUtils qw[uniq];

###
### Entry points
###

sub all {
    my ( $class, $zone ) = @_;
    my @results;

    if ( Zonemaster->config->should_run( 'consistency01' ) ) {
        push @results, $class->consistency01( $zone );
    }
    if ( Zonemaster->config->should_run( 'consistency02' ) ) {
        push @results, $class->consistency02( $zone );
    }
    if ( Zonemaster->config->should_run( 'consistency03' ) ) {
        push @results, $class->consistency03( $zone );
    }
    if ( Zonemaster->config->should_run( 'consistency04' ) ) {
        push @results, $class->consistency04( $zone );
    }
    if ( Zonemaster->config->should_run( 'consistency05' ) ) {
        push @results, $class->consistency05( $zone );
    }

    return @results;
}

###
### Metadata Exposure
###

sub metadata {
    my ( $class ) = @_;

    return {
        consistency01 => [
            qw(
              NO_RESPONSE
              NO_RESPONSE_SOA_QUERY
              ONE_SOA_SERIAL
              MULTIPLE_SOA_SERIALS
              SOA_SERIAL
              SOA_SERIAL_VARIATION
              IPV4_DISABLED
              IPV6_DISABLED
              )
        ],
        consistency02 => [
            qw(
              NO_RESPONSE
              NO_RESPONSE_SOA_QUERY
              ONE_SOA_RNAME
              MULTIPLE_SOA_RNAMES
              SOA_RNAME
              IPV4_DISABLED
              IPV6_DISABLED
              )
        ],
        consistency03 => [
            qw(
              NO_RESPONSE
              NO_RESPONSE_SOA_QUERY
              ONE_SOA_TIME_PARAMETER_SET
              MULTIPLE_SOA_TIME_PARAMETER_SET
              SOA_TIME_PARAMETER_SET
              IPV4_DISABLED
              IPV6_DISABLED
              )
        ],
        consistency04 => [
            qw(
              NO_RESPONSE
              NO_RESPONSE_NS_QUERY
              ONE_NS_SET
              MULTIPLE_NS_SET
              NS_SET
              IPV4_DISABLED
              IPV6_DISABLED
              )
        ],
        consistency05 => [
            qw(
              EXTRA_ADDRESS_PARENT
              EXTRA_ADDRESS_CHILD
              TOTAL_ADDRESS_MISMATCH
              ADDRESSES_MATCH
              )
        ],
    };
} ## end sub metadata

sub translation {
    return {
        'SOA_TIME_PARAMETER_SET' =>
'Saw SOA time parameter set (REFRESH={refresh},RETRY={retry},EXPIRE={expire},MINIMUM={minimum}) on following nameserver set : {servers}.',
        'ONE_SOA_RNAME'                   => 'A single SOA rname value was seen ({rname})',
        'MULTIPLE_SOA_SERIALS'            => 'Saw {count} SOA serial numbers.',
        'SOA_SERIAL'                      => 'Saw SOA serial number {serial} on following nameserver set : {servers}.',
        'SOA_RNAME'                       => 'Saw SOA rname {rname} on following nameserver set : {servers}.',
        'MULTIPLE_SOA_RNAMES'             => 'Saw {count} SOA rname.',
        'ONE_SOA_SERIAL'                  => 'A single SOA serial number was seen ({serial}).',
        'MULTIPLE_SOA_TIME_PARAMETER_SET' => 'Saw {count} SOA time parameter set.',
        'NO_RESPONSE'                     => 'Nameserver {ns}/{address} did not respond.',
        'ONE_SOA_TIME_PARAMETER_SET' =>
'A single SOA time parameter set was seen (REFRESH={refresh},RETRY={retry},EXPIRE={expire},MINIMUM={minimum}).',
        'NO_RESPONSE_SOA_QUERY' => 'No response from nameserver {ns}/{address} on SOA queries.',
        'SOA_SERIAL_VARIATION' =>
'Difference between the smaller serial ({serial_min}) and the bigger one ({serial_max}) is greater than the maximum allowed ({max_variation}).',
        'NO_RESPONSE_NS_QUERY' => 'No response from nameserver {ns}/{address} on NS queries.',
        'ONE_NS_SET'           => 'A unique NS set was seen ({nsset}).',
        'MULTIPLE_NS_SET'      => 'Saw {count} NS set.',
        'NS_SET'               => 'Saw NS set ({nsset}) on following nameserver set : {servers}.',
        'IPV4_DISABLED'        => 'IPv4 is disabled, not sending "{rrtype}" query to {ns}/{address}.',
        'IPV6_DISABLED'        => 'IPv6 is disabled, not sending "{rrtype}" query to {ns}/{address}.',
        'EXTRA_ADDRESS_PARENT' => 'Parent has extra nameserver IP address(es) not listed at child ({addresses}).',
        'EXTRA_ADDRESS_CHILD'  => 'Child has extra nameserver IP address(es) not listed at parent ({addresses}).',
        'TOTAL_ADDRESS_MISMATCH' => 'No common nameserver IP addresses between child ({child}) and parent ({glue}).',
        'ADDRESSES_MATCH'        => 'Glue records are consistent between glue and authoritative data.',
    };
} ## end sub translation

sub version {
    return "$Zonemaster::Test::Consistency::VERSION";
}

###
### Tests
###

sub consistency01 {
    my ( $class, $zone ) = @_;
    my @results;
    my %nsnames_and_ip;
    my %serials;
    my $query_type = q{SOA};

    foreach
      my $local_ns ( @{ Zonemaster::TestMethods->method4( $zone ) }, @{ Zonemaster::TestMethods->method5( $zone ) } )
    {

        next if $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short };

        if ( not Zonemaster->config->ipv6_ok and $local_ns->address->version == $IP_VERSION_6 ) {
            push @results,
              info(
                IPV6_DISABLED => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                    rrtype  => $query_type,
                }
              );
            next;
        }

        if ( not Zonemaster->config->ipv4_ok and $local_ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                    rrtype  => $query_type,
                }
              );
            next;
        }

        my $p = $local_ns->query( $zone->name, $query_type );

        if ( not $p ) {
            push @results,
              info(
                NO_RESPONSE => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                }
              );
            next;
        }

        my ( $soa ) = $p->get_records_for_name( $query_type, $zone->name );

        if ( not $soa ) {
            push @results,
              info(
                NO_RESPONSE_SOA_QUERY => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                }
              );
            next;
        }
        else {
            push @{ $serials{ $soa->serial } }, $local_ns->name->string . q{/} . $local_ns->address->short;
            $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short }++;
        }
    } ## end foreach my $local_ns ( @{ Zonemaster::TestMethods...})

    my @serial_numbers = sort keys %serials;
    if ( scalar( @serial_numbers ) == 1 ) {
        push @results,
          info(
            ONE_SOA_SERIAL => {
                serial => ( keys %serials )[0],
            }
          );
    }
    elsif ( scalar @serial_numbers ) {
        push @results,
          info(
            MULTIPLE_SOA_SERIALS => {
                count => scalar( keys %serials ),
            }
          );
        foreach my $serial ( keys %serials ) {
            push @results,
              info(
                SOA_SERIAL => {
                    serial  => $serial,
                    servers => join( q{;}, sort @{ $serials{$serial} } ),
                }
              );
        }
        if ( $serial_numbers[-1] - $serial_numbers[0] > $MAX_SERIAL_VARIATION ) {
            push @results,
              info(
                SOA_SERIAL_VARIATION => {
                    serial_min    => $serial_numbers[0],
                    serial_max    => $serial_numbers[-1],
                    max_variation => $MAX_SERIAL_VARIATION,
                }
              );
        }
    } ## end elsif ( scalar @serial_numbers)

    return @results;
} ## end sub consistency01

sub consistency02 {
    my ( $class, $zone ) = @_;
    my @results;
    my %nsnames_and_ip;
    my %rnames;
    my $query_type = q{SOA};

    foreach
      my $local_ns ( @{ Zonemaster::TestMethods->method4( $zone ) }, @{ Zonemaster::TestMethods->method5( $zone ) } )
    {

        next if $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short };

        if ( not Zonemaster->config->ipv6_ok and $local_ns->address->version == $IP_VERSION_6 ) {
            push @results,
              info(
                IPV6_DISABLED => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                    rrtype  => $query_type,
                }
              );
            next;
        }

        if ( not Zonemaster->config->ipv4_ok and $local_ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                    rrtype  => $query_type,
                }
              );
            next;
        }

        my $p = $local_ns->query( $zone->name, $query_type );

        if ( not $p ) {
            push @results,
              info(
                NO_RESPONSE => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                }
              );
            next;
        }

        my ( $soa ) = $p->get_records_for_name( $query_type, $zone->name );

        if ( not $soa ) {
            push @results,
              info(
                NO_RESPONSE_SOA_QUERY => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                }
              );
            next;
        }
        else {
            push @{ $rnames{ lc( $soa->rname ) } }, $local_ns->name->string . q{/} . $local_ns->address->short;
            $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short }++;
        }
    } ## end foreach my $local_ns ( @{ Zonemaster::TestMethods...})

    if ( scalar( keys %rnames ) == 1 ) {
        push @results,
          info(
            ONE_SOA_RNAME => {
                rname => ( keys %rnames )[0],
            }
          );
    }
    elsif ( scalar( keys %rnames ) ) {
        push @results,
          info(
            MULTIPLE_SOA_RNAMES => {
                count => scalar( keys %rnames ),
            }
          );
        foreach my $rname ( keys %rnames ) {
            push @results,
              info(
                SOA_RNAME => {
                    rname   => $rname,
                    servers => join( q{;}, @{ $rnames{$rname} } ),
                }
              );
        }
    }

    return @results;
} ## end sub consistency02

sub consistency03 {
    my ( $class, $zone ) = @_;
    my @results;
    my %nsnames_and_ip;
    my %time_parameter_sets;
    my $query_type = q{SOA};

    foreach
      my $local_ns ( @{ Zonemaster::TestMethods->method4( $zone ) }, @{ Zonemaster::TestMethods->method5( $zone ) } )
    {

        next if $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short };

        if ( not Zonemaster->config->ipv6_ok and $local_ns->address->version == $IP_VERSION_6 ) {
            push @results,
              info(
                IPV6_DISABLED => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                    rrtype  => $query_type,
                }
              );
            next;
        }

        if ( not Zonemaster->config->ipv4_ok and $local_ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                    rrtype  => $query_type,
                }
              );
            next;
        }

        my $p = $local_ns->query( $zone->name, $query_type );

        if ( not $p ) {
            push @results,
              info(
                NO_RESPONSE => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                }
              );
            next;
        }

        my ( $soa ) = $p->get_records_for_name( $query_type, $zone->name );

        if ( not $soa ) {
            push @results,
              info(
                NO_RESPONSE_SOA_QUERY => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                }
              );
            next;
        }
        else {
            push
              @{ $time_parameter_sets{ sprintf q{%d;%d;%d;%d}, $soa->refresh, $soa->retry, $soa->expire, $soa->minimum }
              },
              $local_ns->name->string . q{/} . $local_ns->address->short;
            $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short }++;
        }
    } ## end foreach my $local_ns ( @{ Zonemaster::TestMethods...})

    if ( scalar( keys %time_parameter_sets ) == 1 ) {
        my ( $refresh, $retry, $expire, $minimum ) = split /;/sxm, ( keys %time_parameter_sets )[0];
        push @results,
          info(
            ONE_SOA_TIME_PARAMETER_SET => {
                refresh => $refresh,
                retry   => $retry,
                expire  => $expire,
                minimum => $minimum,
            }
          );
    }
    elsif ( scalar( keys %time_parameter_sets ) ) {
        push @results,
          info(
            MULTIPLE_SOA_TIME_PARAMETER_SET => {
                count => scalar( keys %time_parameter_sets ),
            }
          );
        foreach my $time_parameter_set ( keys %time_parameter_sets ) {
            my ( $refresh, $retry, $expire, $minimum ) = split /;/sxm, $time_parameter_set;
            push @results,
              info(
                SOA_TIME_PARAMETER_SET => {
                    refresh => $refresh,
                    retry   => $retry,
                    expire  => $expire,
                    minimum => $minimum,
                    servers => join( q{;}, sort @{ $time_parameter_sets{$time_parameter_set} } ),
                }
              );
        }
    } ## end elsif ( scalar( keys %time_parameter_sets...))

    return @results;
} ## end sub consistency03

sub consistency04 {
    my ( $class, $zone ) = @_;
    my @results;
    my %nsnames_and_ip;
    my %ns_sets;
    my $query_type = q{NS};

    foreach
      my $local_ns ( @{ Zonemaster::TestMethods->method4( $zone ) }, @{ Zonemaster::TestMethods->method5( $zone ) } )
    {

        next if $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short };

        if ( not Zonemaster->config->ipv6_ok and $local_ns->address->version == $IP_VERSION_6 ) {
            push @results,
              info(
                IPV6_DISABLED => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                    rrtype  => $query_type,
                }
              );
            next;
        }

        if ( not Zonemaster->config->ipv4_ok and $local_ns->address->version == $IP_VERSION_4 ) {
            push @results,
              info(
                IPV4_DISABLED => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                    rrtype  => $query_type,
                }
              );
            next;
        }

        my $p = $local_ns->query( $zone->name, $query_type );

        if ( not $p ) {
            push @results,
              info(
                NO_RESPONSE => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                }
              );
            next;
        }

        my ( @ns ) = sort map { lc( $_->nsdname ) } $p->get_records_for_name( $query_type, $zone->name );

        if ( not scalar( @ns ) ) {
            push @results,
              info(
                NO_RESPONSE_NS_QUERY => {
                    ns      => $local_ns->name->string,
                    address => $local_ns->address->short,
                }
              );
            next;
        }
        else {
            push @{ $ns_sets{ join( q{,}, @ns ) } }, $local_ns->name->string . q{/} . $local_ns->address->short;
            $nsnames_and_ip{ $local_ns->name->string . q{/} . $local_ns->address->short }++;
        }
    } ## end foreach my $local_ns ( @{ Zonemaster::TestMethods...})

    if ( scalar( keys %ns_sets ) == 1 ) {
        push @results,
          info(
            ONE_NS_SET => {
                nsset => ( keys %ns_sets )[0],
            }
          );
    }
    elsif ( scalar( keys %ns_sets ) ) {
        push @results,
          info(
            MULTIPLE_NS_SET => {
                count => scalar( keys %ns_sets ),
            }
          );
        foreach my $ns_set ( keys %ns_sets ) {
            push @results,
              info(
                NS_SET => {
                    nsset   => $ns_set,
                    servers => join( q{;}, @{ $ns_sets{$ns_set} } ),
                }
              );
        }
    }

    return @results;
} ## end sub consistency04

sub consistency05 {
    my ( $class, $zone ) = @_;
    my @results;

    my %addresses;
    foreach my $address ( uniq map { lc( $_->address->short ) } @{ Zonemaster::TestMethods->method4( $zone ) } ) {
        $addresses{$address} += 1;
    }
    foreach my $address ( uniq map { lc( $_->address->short ) } @{ Zonemaster::TestMethods->method5( $zone ) } ) {
        $addresses{$address} -= 1;
    }

    my @same_address         = sort grep { $addresses{$_} == 0 } keys %addresses;
    my @extra_address_parent = sort grep { $addresses{$_} > 0 } keys %addresses;
    my @extra_address_child  = sort grep { $addresses{$_} < 0 } keys %addresses;

    if ( @extra_address_parent ) {
        push @results,
          info(
            EXTRA_ADDRESS_PARENT => {
                addresses => join( q{;}, @extra_address_parent ),
            }
          );
    }

    if ( @extra_address_child ) {
        push @results,
          info(
            EXTRA_ADDRESS_CHILD => {
                addresses => join( q{;}, @extra_address_child ),
            }
          );
    }

    if ( @extra_address_parent == 0 and @extra_address_child == 0 ) {
        push @results,
          info(
            ADDRESSES_MATCH => {
                addresses => join( q{;}, @same_address ),
            }
          );
    }

    if ( scalar( @same_address ) == 0 ) {
        push @results,
          info(
            TOTAL_ADDRESS_MISMATCH => {
                glue  => join( q{;}, @extra_address_parent ),
                child => join( q{;}, @extra_address_child ),
            }
          );
    }

    return @results;
} ## end sub consistency05

1;

=head1 NAME

Zonemaster::Test::Consistency - Consistency module showing the expected structure of Zonemaster test modules

=head1 SYNOPSIS

    my @results = Zonemaster::Test::Consistency->all($zone);

=head1 METHODS

=over

=item all($zone)

Runs the default set of tests and returns a list of log entries made by the tests.

=item metadata()

Returns a reference to a hash, the keys of which are the names of all test methods in the module, and the corresponding values are references to
lists with all the tags that the method can use in log entries.

=item translation()

Returns a refernce to a hash with translation data. Used by the builtin translation system.

=item version()

Returns a version string for the module.

=back

=head1 TESTS

=over

=item consistency01($zone)

Query all nameservers for SOA, and see that they all have the same SOA serial number.

=item consistency02($zone)

Query all nameservers for SOA, and see that they all have the same SOA rname.

=item consistency03($zone)

Query all nameservers for SOA, and see that they all have the same time parameters (REFRESH/RETRY/EXPIRE/MINIMUM).

=item consistency04($zone)

Query all nameservers for NS set, and see that they have all the same content.

=item consistency05($zone)

Verify that the glue records are consistent between glue and authoritative data.

=back

=cut
