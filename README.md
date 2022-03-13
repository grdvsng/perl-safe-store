# SaveStore
#### Description
Simple memory safe store for Perl

#### Samury
``` perl
use strict;
use warnings;
use SafeStore;
use Data::Dumper;
use Parallel::ForkManager; 

my $store = SafeStore->new;
my @array = qw( a b c d );
my $pm    = Parallel::ForkManager->new( $#array );

LOOP:
for my $i ( @array )
{
    my $pid = $pm->start and nextr LOOP;
    my $trn = $store->edit;
     
    sleep( rand( 2 ) );

    $trn->edit( $i => rand( 10 ) );
    
    $trn->commit;
    
    $pm->finish;
}

$pm->wait_all_children;

print( Dumper( $store->store ) );
#>> { a => 1, b => 3, d => 2, c => 6 }

$store->rallback;

print( Dumper( $store->store ) );
#>> { a => 1, b => 3, d => 2 }
```