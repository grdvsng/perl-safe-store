package SafeStore;
{
    use Moose;
    use JSON::PP;
    use Data::GUID;
    use Data::Dumper;
    use SafeStore::File;
    use SafeStore::Transaction;
    use Time::HiRes qw( usleep );
    use File::Temp qw( tempdir );
    use feature qw( signatures say );
    use File::Spec::Functions 'catfile';
    use SafeStore::Error::KeyNotExists;
    use SafeStore::Error::RollbackIsImpossible;
    #~ ------------------------------------------------------------------------- ~#
    extends 'SafeStore::Class';
    #~ ------------------------------------------------------------------------- ~#
    has 'id'      => ( is=>'ro', isa=>'Str'                               , lazy=>1, default=>sub{ Data::GUID->new->as_string              } );
    has 'holder'  => ( is=>'ro', isa=>'Str'                               , lazy=>1, default=>sub{ catfile( tempdir( ), $_[0]->id.'.tmp' ) } );
    has 'blocked' => ( is=>'rw', isa=>'Bool'                              , default=>0                                                       );
    has 'history' => ( is=>'rw', isa=>'ArrayRef[HashRef[Str|Int]]'        , default=>sub { [ ] }                                             );
    has 'changes' => ( is=>'rw', isa=>'ArrayRef[SafeStore::Transaction]'  , default=>sub { [ ] }                                             );
    has 'store'   => ( is=>'rw', isa=>'HashRef[Str|Int]'                  , default=>sub { { } }                                             );
    #~ ------------------------------------------------------------------------- ~#
    sub new( $cls, @args )
    {
        my $self = $cls->SUPER::new( @args );
        my $file = SafeStore::File->new( path=>$self->holder );

        $file->create_if_not_exists;
        $self->sync;

        return $self;
    }

    sub edit( $self )
    {
        my $store = SafeStore::Transaction->new( master => $self );
        my $file  = SafeStore::File->new( path=>$self->holder );

        $self->safe( sub { 
            $self->sync;

            push( @{ $self->changes }, $store );
            
            $file->write( encode_json( $self->pack ), '>' );
        } );

        return $store;
    }

    sub read( $self )
    {
        return $self->sync->store->data;
    }

    sub clear( $self )
    {
        my $file = SafeStore::File->new( path=>$self->holder );

        $file->remove;
        $file->create_if_not_exists;

        $self->sync;
    }

    sub __commit( $self, $store )
    {
        $self->safe( sub {
            $self->sync;

            my $file = SafeStore::File->new( path=>$self->holder );
            
            push( @{ $self->history }, { %{ $self->store }, '__id__' => $store->id } );

            my $data =  { %{ $self->store }, %{ $store->data } };

            for my $key ( @{ $store->remove_data } )
            {
                delete $data->{ $key };
            }
 
            $self->store( $data );
         
            $store->commited       ( 1                             );
            $store->commit_position( scalar( @{ $self->history } ) );

            $file->write( encode_json( $self->pack ), '>' );
        } ); 
    }

    sub commit( $self, $store_id=undef )
    {
        for my $store ( @{ $self->changes } )
        {
            if ( !$store_id )
            {
                $self->__commit( $store );
            } elsif ( $store_id eq $store->id ) {
                $self->__commit( $store );
            }
        }
    }

    sub safe( $self, $callback )
    {
        $self->wait;
        $self->block;
      
        my $result = $callback->( );

        $self->unblock;

        return $result;
    }

    sub wait( $self )
    {
        usleep( rand( 500 ) ) while $self->status;
    }

    sub unblock( $self )
    {
        $self->blocked( 0 );
        $self->sync;
        
        my $file = SafeStore::File->new( path=>$self->holder );

        $file->write( encode_json( $self->pack ), '>' );
    }

    sub block( $self )
    {
        
        $self->sync;
        $self->blocked( 1 );
        
        my $file = SafeStore::File->new( path=>$self->holder );

        $file->write( encode_json( $self->pack ), '>' );
    }

    sub status( $self )
    {
        my $file = SafeStore::File->new( path=>$self->holder );

        if ( my $content = $file->read )
        {
            my $data = decode_json( $content );

            $self->blocked( $data->{blocked} );
        }    

        return $self->blocked;
    }

    sub sync( $self )
    {
        my $file = SafeStore::File->new( path=>$self->holder );

        if ( my $content = $file->read )
        {
            my $data = decode_json( $content );
            
            my @changes = ( );

            for my $change ( @{ $data->{changes} } )
            {
                $change         = SafeStore::Transaction->new( %$change, master => $self );
                my ( $founded ) = grep( { $_->id eq $change->id } @{ $self->changes } );

                if ( !$founded )
                {
                    push( @changes, $change );
                } else {
                    push( @changes, $founded );
                }
            }
            
            $self->changes( \@changes );
            
            $self->history( $data->{history} );
            
            $self->store( $data->{store} || { } );
        }

        return $self;
    }

    sub __rollback( $self, $store )
    {
        $self->sync;

        my $file = SafeStore::File->new( path=>$self->holder );

        my @changes = ( );
        my @history = ( ); 

        for my $change ( @{ $self->changes } )
        {
            last if $change->id eq $store->{__id__};
           
            push( @changes, $change );
        }

        for my $history ( @{ $self->history } )
        {
            last if $history->{__id__} eq $store->{__id__};
           
            push( @history, $history );
        }

        $self->history( \@history );
        $self->changes( [ sort( { $a->commit_position ge $b->commit_position } @changes ) ] );

        delete $store->{__id__};

        $self->store( $store );

        $file->write( encode_json( $self->pack ), '>' );
    }

    sub rollback( $self, $id=undef )
    {
        if ( scalar( @{ $self->history } ) > 0 )
        {
            $self->safe( sub { 
                my $id_exists = undef;
                
                $id ||= $self->history->[ scalar( @{ $self->history } ) - 1 ]->{__id__};

                for my $store ( @{ $self->history } )
                {
                    if ( $id eq $store->{__id__} )
                    {
                        $id_exists = 1;
                        
                        $self->__rollback( $store );
                    }
                }

                if ( !$id_exists )
                {
                    SafeStore::Error::RollbackIsImpossible->raise( "Change with id='$id' not exists" );
                }
            } );
        } else {
            SafeStore::Error::RollbackIsImpossible->raise( 'Store is clean' );
        }
    }

    sub get( $self, $key )
    {
        $self->sync;

        SafeStore::Error::KeyNotExists->raise( $key ) if !exists( $self->store->{$key} );

        return $self->store->{$key};
    }

    sub set( $self, $key, $value )
    {
        my $transaction = $self->edit;

        $transaction->set( $key, $value );

        $transaction->commit;
    }

    sub remove( $self, $key )
    {
        my $transaction = $self->edit;

        $transaction->remove( $key );

        $transaction->commit;
    }
};
1;