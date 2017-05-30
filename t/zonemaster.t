use Test::More;
use Test::Fatal;
use File::Temp qw[:POSIX];

BEGIN {
    use_ok( 'Zonemaster::Engine' );
    use_ok( 'Zonemaster::Engine::Test' );
    use_ok( 'Zonemaster::Engine::Nameserver' );
    use_ok( 'Zonemaster::Engine::Exception' );
}

is( exception { Zonemaster::Engine->reset(); }, undef, 'No crash on instant reset.');

my $datafile = q{t/zonemaster.data};
if ( not $ENV{ZONEMASTER_RECORD} ) {
    die q{Stored data file missing} if not -r $datafile;
    Zonemaster::Engine::Nameserver->restore( $datafile );
    Zonemaster::Engine->config->no_network( 1 );
}

isa_ok( Zonemaster::Engine->logger, 'Zonemaster::Logger' );
isa_ok( Zonemaster::Engine->config, 'Zonemaster::Config' );

my %module = map { $_ => 1 } Zonemaster::Engine::Test->modules;

ok( $module{Consistency},  'Consistency' );
ok( $module{Delegation},   'Delegation' );
ok( $module{Syntax},       'Syntax' );
ok( $module{Connectivity}, 'Connectivity' );

my %methods = Zonemaster::Engine->all_methods;
ok( exists( $methods{Basic} ), 'all_methods' );

my @tags = Zonemaster::Engine->all_tags;
ok( ( grep { /BASIC:HAS_NAMESERVERS/ } @tags ), 'all_tags' );

my $disabled           = 0;
my $dependency_version = 0;
my $global_version     = 0;
%module = ();
%end    = ();
Zonemaster::Engine->logger->callback(
    sub {
        my ( $e ) = shift;

        if ( $e->tag eq 'POLICY_DISABLED' and $e->args->{name} eq 'Example' ) {
            $disabled = 1;
        }

        if ( $e->tag eq 'MODULE_VERSION' ) {
            $module{ $e->args->{module} } = $e->args->{version};
        }

        if ( $e->tag eq 'MODULE_END' ) {
            $end{ $e->args->{module} } = 1;
        }

        if ( $e->tag eq 'GLOBAL_VERSION' ) {
            $global_version = $e->args->{version};
        }

        if ( $e->tag eq 'DEPENDENCY_VERSION' ) {
            $dependency_version = 1;
        }

    }
);
my @results = Zonemaster::Engine->test_zone( 'nic.se' );

ok( $global_version,     "Global version: $global_version" );
ok( $dependency_version, 'At least one dependency version logged' );

ok( $module{'Zonemaster::Engine::Test::Address'},      'Zonemaster::Test::Address did run.' );
ok( $module{'Zonemaster::Engine::Test::Basic'},        'Zonemaster::Test::Basic did run.' );
ok( $module{'Zonemaster::Engine::Test::Connectivity'}, 'Zonemaster::Test::Connectivity did run.' );
ok( $module{'Zonemaster::Engine::Test::Consistency'},  'Zonemaster::Test::Consistency did run.' );
ok( $module{'Zonemaster::Engine::Test::DNSSEC'},       'Zonemaster::Test::DNSSEC did run.' );
ok( $module{'Zonemaster::Engine::Test::Delegation'},   'Zonemaster::Test::Delegation did run.' );
ok( $module{'Zonemaster::Engine::Test::Nameserver'},   'Zonemaster::Test::Nameserver did run.' );
ok( $module{'Zonemaster::Engine::Test::Syntax'},       'Zonemaster::Test::Syntax did run.' );
ok( $module{'Zonemaster::Engine::Test::Zone'},         'Zonemaster::Test::Zone did run.' );

ok( $end{'Zonemaster::Engine::Test::Address'},      'Zonemaster::Test::Address did end.' );
ok( $end{'Zonemaster::Engine::Test::Basic'},        'Zonemaster::Test::Basic did end.' );
ok( $end{'Zonemaster::Engine::Test::Connectivity'}, 'Zonemaster::Test::Connectivity did end.' );
ok( $end{'Zonemaster::Engine::Test::Consistency'},  'Zonemaster::Test::Consistency did end.' );
ok( $end{'Zonemaster::Engine::Test::DNSSEC'},       'Zonemaster::Test::DNSSEC did end.' );
ok( $end{'Zonemaster::Engine::Test::Delegation'},   'Zonemaster::Test::Delegation did end.' );
ok( $end{'Zonemaster::Engine::Test::Nameserver'},   'Zonemaster::Test::Nameserver did end.' );
ok( $end{'Zonemaster::Engine::Test::Syntax'},       'Zonemaster::Test::Syntax did end.' );
ok( $end{'Zonemaster::Engine::Test::Zone'},         'Zonemaster::Test::Zone did end.' );

ok( $disabled, 'Blocking of disabled module was logged.' );

my $filename = tmpnam();
Zonemaster::Engine->save_cache( $filename );
my $save_entry = Zonemaster::Engine->logger->entries->[-1];
Zonemaster::Engine->preload_cache( $filename );
my $restore_entry = Zonemaster::Engine->logger->entries->[-1];
is( $save_entry->tag,             'SAVED_NS_CACHE',    'Saving worked.' );
is( $save_entry->args->{file},    $filename,           'To the right file name.' );
is( $restore_entry->tag,          'RESTORED_NS_CACHE', 'Restoring worked.' );
is( $restore_entry->args->{file}, $filename,           'From the right file name.' );
unlink( $filename );

Zonemaster::Engine->test_module( 'gurksallad', 'nic.se' );
is( Zonemaster::Engine->logger->entries->[-1]->tag, 'UNKNOWN_MODULE', 'Proper message for unknown module' );

Zonemaster::Engine->test_method( 'gurksallad', 'nic.se' );
is( Zonemaster::Engine->logger->entries->[-1]->tag, 'UNKNOWN_MODULE', 'Proper message for unknown module' );

Zonemaster::Engine->test_method( 'basic', 'basic17' );
is( Zonemaster::Engine->logger->entries->[-1]->tag, 'UNKNOWN_METHOD', 'Proper message for unknown method' );

# Test exceptions in callbacks
Zonemaster::Engine->logger->callback(
    sub {
        my ( $e ) = @_;
        return if ( $e->module eq 'SYSTEM' or $e->module eq 'BASIC' );
        die Zonemaster::Engine::Exception->new( { message => 'canary' } );
    }
);
isa_ok( exception { Zonemaster::Engine->test_zone( 'nic.se' ) }, 'Zonemaster::Exception' );
isa_ok( exception { Zonemaster::Engine->test_module( 'SyNtAx', 'nic.se' ) }, 'Zonemaster::Exception' );
isa_ok( exception { Zonemaster::Engine->test_method( 'Syntax', 'syntax01', 'nic.se' ) }, 'Zonemaster::Exception' );
Zonemaster::Engine->logger->clear_callback;

Zonemaster::Engine->config->ipv4_ok( 0 );
Zonemaster::Engine->config->ipv6_ok( 0 );
my ( $msg ) = Zonemaster::Engine->test_zone( 'nic.se' );
ok( !!$msg, 'Got a message.' );
is( $msg->tag, 'NO_NETWORK', 'It is the right message.' );

( $msg ) = Zonemaster::Engine->test_module( 'Basic', 'nic.se' );
ok( !!$msg, 'Got a message.' );
is( $msg->tag, 'NO_NETWORK', 'It is the right message.' );

( $msg ) = Zonemaster::Engine->test_method( 'Basic', 'basic01', 'nic.se' );
ok( !!$msg, 'Got a message.' );
is( $msg->tag, 'NO_NETWORK', 'It is the right message.' );
Zonemaster::Engine->config->ipv4_ok( 1 );
Zonemaster::Engine->config->ipv6_ok( 1 );

if ( $ENV{ZONEMASTER_RECORD} ) {
    Zonemaster::Engine::Nameserver->save( $datafile );
}

ok( @{ Zonemaster::Engine->logger->entries } > 0,                        'There are log entries' );
ok( scalar( keys( %Zonemaster::Engine::Nameserver::object_cache ) ) > 0, 'There are things in the object cache' );
Zonemaster::Engine->reset;
ok( @{ Zonemaster::Engine->logger->entries } == 0,                        'There are no log entries' );
ok( scalar( keys( %Zonemaster::Engine::Nameserver::object_cache ) ) == 0, 'The object cache is empty' );
ok( scalar( keys( %Zonemaster::Engine::Nameserver::Cache::object_cache ) ) == 0, 'The packet cache is empty' );

done_testing;
