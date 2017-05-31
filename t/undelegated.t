use Test::More;

use 5.12.4;

use Zonemaster;
use Zonemaster::Engine::Nameserver;
use Zonemaster::Engine::Util;

###
my $datafile = 't/undelegated.data';
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die "Stored data file missing" if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster->config->no_network( 1 );
}
###

my $plain_p = Zonemaster->recurse( 'www.lysator.liu.se', 'AAAA' );
isa_ok( $plain_p, 'Zonemaster::Packet' );
ok( $plain_p,        'Got answer' );

Zonemaster->add_fake_delegation(
    'lysator.liu.se.' => {
        'ns-slave.lysator.liu.se'  => [ '130.236.254.4',  '130.236.255.2' ],
        'ns-master.lysator.liu.se' => [ '130.236.254.2', '2001:6b0:17:f0a0::2' ],
        'ns-slave-1.ifm.liu.se'    => [ '130.236.160.2',  '2001:6b0:17:f180::1001' ],
        'ns-slave-2.ifm.liu.se'    => [ '130.236.160.3',  '2001:6b0:17:f180::1002' ]
    }
);

my $fake_happened = 0;
Zonemaster->logger->callback(
    sub {
        $fake_happened = 1 if $_[0]->tag eq 'FAKE_DELEGATION';
    }
);

my $fake_p = Zonemaster->recurse( 'www.lysator.liu.se', 'AAAA' );
ok( $fake_happened, 'Fake delegation logged' );
ok( $fake_p,        'Got answer' );
if ( $fake_p ) {
    is( $fake_p->rcode, 'NOERROR', 'expected RCODE' );
}
Zonemaster->logger->clear_callback;

Zonemaster->add_fake_ds( 'lysator.liu.se' => [ { keytag => 4711, algorithm => 17, type => 42, digest => 'FACEB00C' } ],
);

my $lys = Zonemaster->zone( 'lysator.liu.se' );
my $ds_p = $lys->parent->query_one( 'lysator.liu.se', 'DS' );
isa_ok( $ds_p, 'Zonemaster::Packet' );
my ( $ds ) = $ds_p->answer;
isa_ok( $ds, 'Net::LDNS::RR::DS' );
is( $ds->hexdigest, 'faceb00c', 'Correct digest' );

Zonemaster->logger->clear_history;
Zonemaster->add_fake_delegation(
    'nic.se.' => {
        'ns.nic.se'  => [ '212.247.7.228',  '2a00:801:f0:53::53' ],
        'i.ns.se'    => [ '194.146.106.22', '2001:67c:1010:5::53' ],
        'ns3.nic.se' => [ '212.247.8.152',  '2a00:801:f0:211::152' ]
    }
);
ok( !!( grep { $_->tag eq 'FAKE_DELEGATION_TO_SELF' } @{ Zonemaster->logger->entries } ),
    'Refused adding circular fake delegation.' );

Zonemaster->logger->clear_history;
Zonemaster->add_fake_delegation(
    'lysator.liu.se.' => {
        'frfr.sesefrfr'  => [ ],
        'i.ns.se'        => [ '194.146.106.22', '2001:67c:1010:5::53' ],
        'ns3.nic.se'     => [ '212.247.8.152',  '2a00:801:f0:211::152' ]
    }
);

ok( !!( grep { $_->tag eq 'FAKE_DELEGATION_NO_IP' } @{ Zonemaster->logger->entries } ),
    'Refused fake delegation without IP address for bad ns.' );

Zonemaster->logger->clear_history;
Zonemaster->add_fake_delegation(
    'nic.se.' => {
        'ns.nic.se'  => [ '212.247.7.228',  '2a00:801:f0:53::53' ],
        'i.ns.se'    => [ '194.146.106.22', '2001:67c:1010:5::53' ],
        'ns3.nic.se' => [ '212.247.8.152',  '2a00:801:f0:211::152' ],
        'ns4.nic.se' => [ ]
    }
);

ok( !!( grep { $_->tag eq 'FAKE_DELEGATION_IN_ZONE_NO_IP' } @{ Zonemaster->logger->entries } ),
    'Refused in-zone fake delegation without IP address.' );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
