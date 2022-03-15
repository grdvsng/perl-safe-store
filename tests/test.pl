#! /usr/lib/perl
use strict;
use warnings;
use threads;
use JSON::PP;
use Error::Simple;
use Data::Dumper;
use File::Basename;
use Test::Exception;
use threads::shared;
use feature qw( say );
use Test::More 'no_plan';
use Parallel::ForkManager;
use lib dirname( dirname( $0 ) );
#~ ------------------------------------------ ~#
require_ok( "SafeStore" );
#~ ------------------------------------------ ~#
#? One thread using
ok( my $store = SafeStore->new( id=>'save_store_usual' ), 'Create SafeStore' );

lives_ok( sub { $store->clear }, 'Clear SafeStore' );

throws_ok( sub { $store->rollback }, 'SafeStore::Error::RollbackIsImpossible' );

ok( my $trn0 = $store->edit, 'Create first  transaction' );
ok( my $trn1 = $store->edit, 'Create second transaction' );

lives_ok( sub { $trn0->set( 'hello' => 'world' )->commit }, 'Set key hello' );
lives_ok( sub { $trn1->set( 'perl'  => 'monc'  )->commit }, 'Set key perl'  );

is( $store->get( 'hello' ), 'world', 'Check key hello has correct value' );
is( $store->get( 'perl'  ), 'monc' , 'Check key perl  has correct value' );

lives_ok( sub { $store->rollback }, 'Store rollback' );

throws_ok( sub { $store->get( 'perl' ) }, 'SafeStore::Error::KeyNotExists' );

is( $store->get( 'hello' ), 'world', 'Check key hello has correct value' );

lives_ok( sub { $store->set( 'perl', 'monc' ) }, 'Set store' );

is( $store->get( 'perl'  ), 'monc' , 'Check key perl  has correct value' );

#? Using multy process
ok( my $store = SafeStore->new( id=>'save_store_forks' ), 'Create SafeStore' );

lives_ok( sub { $store->clear }, 'Clear SafeStore' );

throws_ok( sub { $store->rollback }, 'SafeStore::Error::RollbackIsImpossible' );

my %temp = (
    'hello' => 'world',
    'perl'  => 'monc',
);

my @keys = keys( %temp );
my $pm = Parallel::ForkManager->new( $#keys );

FORK_CREATE_TRNS_LOOP:
for my $i ( 0..$#keys )
{
    my $pid = $pm->start and next FORK_CREATE_TRNS_LOOP;
    my $key = $keys[ $i ];
    
    ok( my $trn = $store->edit, 'Create '.( $i + 1 ).' transaction' );

    lives_ok( sub { $trn->set( $key => $temp{$key} ) }, "Set key $key" );

    $trn->commit;
    $pm->finish;
}

$pm->wait_all_children;

is( $store->get( 'hello' ), 'world', 'Check key hello has correct value' );
is( $store->get( 'perl'  ), 'monc' , 'Check key perl  has correct value' );

FORK_REMOVE_TRNS_LOOP:
for my $i ( 0..$#keys )
{
    my $pid = $pm->start and next FORK_REMOVE_TRNS_LOOP;
    my $key = $keys[ $i ];
    
    ok( my $trn = $store->edit, 'Create '.( $i + 1 ).' transaction' );

    lives_ok( sub { $trn->remove( $key ) }, "Remove key $key" ) if $key eq 'hello';

    $trn->commit;
    $pm->finish;
}

$pm->wait_all_children;

throws_ok( sub { $store->get( 'hello' ) }, 'SafeStore::Error::KeyNotExists' );

lives_ok( sub { $store->rollback }, 'Store rollback' );

is( $store->get( 'hello' ), 'world', 'Check key hello has correct value' );
is( $store->get( 'perl'  ), 'monc' , 'Check key perl  has correct value' );
