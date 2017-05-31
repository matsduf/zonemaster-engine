use Test::More;

use List::MoreUtils qw[uniq none any];

BEGIN {
    use_ok( q{Zonemaster} );
    use_ok( q{Zonemaster::Engine::Nameserver} );
    use_ok( q{Zonemaster::DNSName} );
    use_ok( q{Zonemaster::Zone} );
    use_ok( q{Zonemaster::Engine::Test::Syntax} );
}

sub name_gives {
    my ( $test, $name, $gives ) = @_;

    my @res = Zonemaster->test_method( q{Syntax}, $test, $name );
    ok( ( grep { $_->tag eq $gives } @res ), "$name gives $gives" );
}

sub name_gives_not {
    my ( $test, $name, $gives ) = @_;

    my @res = Zonemaster->test_method( q{Syntax}, $test, $name );
    ok( !( grep { $_->tag eq $gives } @res ), "$name does not give $gives" );
}

sub zone_gives {
    my ( $test, $zone, $gives ) = @_;

    my @res = Zonemaster->test_method( q{Syntax}, $test, $zone );
    ok( ( grep { $_->tag eq $gives } @res ), $zone->name->string . " gives $gives" );
}

sub zone_gives_not {
    my ( $test, $zone, $gives ) = @_;

    my @res = Zonemaster->test_method( q{Syntax}, $test, $zone );
    ok( !( grep { $_->tag eq $gives } @res ), $zone->name->string . " does not give $gives" );
}

my $datafile = q{t/Test-syntax.data};
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster->config->no_network( 1 );
}

# Find a way with dependences for syntax04 syntax05 syntax06 syntax07 syntax08
foreach my $testcase ( qw{syntax01 syntax02 syntax03} ) {
    Zonemaster->config->load_policy_file( 't/policies/Test-'.$testcase.'-only.json' );
    my @testcases;
    foreach my $result ( Zonemaster->test_module( q{syntax}, q{afnic.fr} ) ) {
        foreach my $trace (@{$result->trace}) {
            push @testcases, grep /Zonemaster::Engine::Test::Syntax::syntax/, @$trace;
        }
    }
    @testcases = uniq sort @testcases;
    is( scalar( @testcases ), 1, 'only one test-case' );
    is( $testcases[0], 'Zonemaster::Engine::Test::Syntax::'.$testcase, 'expected test-case' );
}

Zonemaster->config->load_policy_file( 't/policies/Test-syntax-all.json' );

my $ns_ok = Zonemaster::DNSName->new( q{ns1.nic.fr} );
my $dn_ok = Zonemaster::DNSName->new( q{www.nic.se} );
my $dn_ko = Zonemaster::DNSName->new( q{www.nic&nac.se} );
name_gives( q{syntax01}, $dn_ok, q{ONLY_ALLOWED_CHARS} );
name_gives_not( q{syntax01}, $dn_ko, q{ONLY_ALLOWED_CHARS} );
name_gives( q{syntax01}, $dn_ko, q{NON_ALLOWED_CHARS} );
name_gives_not( q{syntax01}, $dn_ok, q{NON_ALLOWED_CHARS} );

$dn_ko = Zonemaster::DNSName->new( q{www.-nic.se} );
name_gives( q{syntax02}, $dn_ko, q{INITIAL_HYPHEN} );
name_gives_not( q{syntax02}, $dn_ko, q{NO_ENDING_HYPHENS} );
name_gives_not( q{syntax02}, $dn_ok, q{INITIAL_HYPHEN} );
name_gives( q{syntax02}, $dn_ok, q{NO_ENDING_HYPHENS} );

$dn_ko = Zonemaster::DNSName->new( q{www.nic-.se} );
name_gives( q{syntax02}, $dn_ko, q{TERMINAL_HYPHEN} );
name_gives_not( q{syntax02}, $dn_ko, q{NO_ENDING_HYPHENS} );
name_gives_not( q{syntax02}, $dn_ok, q{TERMINAL_HYPHEN} );

my $dn_idn_ok = Zonemaster::DNSName->new( q{www.xn--nic.se} );
$dn_ko = Zonemaster::DNSName->new( q{www.ni--c.se} );
name_gives( q{syntax03}, $dn_ko, q{DISCOURAGED_DOUBLE_DASH} );
name_gives_not( q{syntax03}, $dn_ko,     q{NO_DOUBLE_DASH} );
name_gives_not( q{syntax03}, $dn_ok,     q{DISCOURAGED_DOUBLE_DASH} );
name_gives_not( q{syntax03}, $dn_idn_ok, q{DISCOURAGED_DOUBLE_DASH} );
name_gives( q{syntax03}, $dn_ok,     q{NO_DOUBLE_DASH} );
name_gives( q{syntax03}, $dn_idn_ok, q{NO_DOUBLE_DASH} );

my $ns_double_dash = Zonemaster::DNSName->new( q{ns1.ns--nic.fr} );
name_gives( q{syntax04}, $ns_double_dash, q{NAMESERVER_DISCOURAGED_DOUBLE_DASH} );
name_gives_not( q{syntax04}, $ns_ok, q{NAMESERVER_DISCOURAGED_DOUBLE_DASH} );

my $ns_num_tld = Zonemaster::DNSName->new( q{ns1.nic.47} );
name_gives( q{syntax04}, $ns_num_tld, q{NAMESERVER_NUMERIC_TLD} );
name_gives_not( q{syntax04}, $ns_ok, q{NAMESERVER_NUMERIC_TLD} );

my %res;
my $zone;

$zone = Zonemaster->zone( q{afnic.fr} );
zone_gives( q{syntax05}, $zone, q{RNAME_NO_AT_SIGN} );
zone_gives_not( q{syntax05}, $zone, q{RNAME_MISUSED_AT_SIGN} );
zone_gives( q{syntax06}, $zone, q{RNAME_RFC822_VALID} );
zone_gives_not( q{syntax06}, $zone, q{RNAME_RFC822_INVALID} );
zone_gives_not( q{syntax07}, $zone, q{MNAME_DISCOURAGED_DOUBLE_DASH} );
zone_gives_not( q{syntax07}, $zone, q{MNAME_NUMERIC_TLD} );
zone_gives_not( q{syntax07}, $zone, q{NO_RESPONSE_SOA_QUERY} );
zone_gives_not( q{syntax08}, $zone, q{MX_DISCOURAGED_DOUBLE_DASH} );
zone_gives_not( q{syntax08}, $zone, q{MX_NUMERIC_TLD} );
zone_gives_not( q{syntax08}, $zone, q{NO_RESPONSE_MX_QUERY} );
zone_gives_not( q{syntax06}, $zone, q{NO_RESPONSE_SOA_QUERY} );

$zone = Zonemaster->zone( q{syntax01.zut-root.rd.nic.fr} );
zone_gives( q{syntax05}, $zone, q{RNAME_MISUSED_AT_SIGN} );
zone_gives_not( q{syntax05}, $zone, q{RNAME_NO_AT_SIGN} );
zone_gives_not( q{syntax06}, $zone, q{RNAME_RFC822_VALID} );
zone_gives( q{syntax06}, $zone, q{RNAME_RFC822_INVALID} );
zone_gives( q{syntax07}, $zone, q{MNAME_DISCOURAGED_DOUBLE_DASH} );
zone_gives( q{syntax07}, $zone, q{MNAME_NUMERIC_TLD} );
zone_gives_not( q{syntax06}, $zone, q{NO_RESPONSE_SOA_QUERY} );
zone_gives( q{syntax08}, $zone, q{MX_NUMERIC_TLD} );
zone_gives( q{syntax08}, $zone, q{MX_DISCOURAGED_DOUBLE_DASH} );
zone_gives_not( q{syntax08}, $zone, q{NO_RESPONSE_MX_QUERY} );
zone_gives_not( q{syntax06}, $zone, q{NO_RESPONSE_SOA_QUERY} );

$zone = Zonemaster->zone( 'name.doesnotexist' );
%res = map { $_->tag => 1 } Zonemaster->test_method( q{Syntax}, q{syntax05}, $zone );
ok( $res{NO_RESPONSE_SOA_QUERY}, q{No response from nameserver(s) on SOA queries} );
%res = map { $_->tag => 1 } Zonemaster->test_method( q{Syntax}, q{syntax06}, $zone );
ok( $res{NO_RESPONSE_SOA_QUERY}, q{No response from nameserver(s) on SOA queries} );
%res = map { $_->tag => 1 } Zonemaster->test_method( q{Syntax}, q{syntax07}, $zone );
ok( $res{NO_RESPONSE_SOA_QUERY}, q{No response from nameserver(s) on SOA queries} );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

done_testing;
