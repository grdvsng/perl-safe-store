package SafeStore::Transaction;
{
    use Moose;
    use DateTime;
    use Data::GUID;
    use Error::Simple;
    use feature qw( signatures );
    use SafeStore::Error::StoreCommited;
    #~ ---------------- ~#
    extends 'SafeStore::Class';
    #~ ---------------- ~#
    has 'id'              => ( is=>'ro', isa=>'Str'                  , default=>sub{ Data::GUID->new->as_string } );
    has 'commit_position' => ( is=>'rw', isa=>'Int'                                                               );
    has 'created_time'    => ( is=>'ro', isa=>'Str'                  , default=>sub{ DateTime->now.'' }           );
    has 'process'         => ( is=>'ro', isa=>'Str'                  , default=>sub{ "$$" }                       );
    has 'data'            => ( is=>'rw', isa=>'HashRef[Str|Int]'     , default=>sub { return { } }                );
    has 'edit_time'       => ( is=>'rw', isa=>'Str'                                                               );
    has 'master'          => ( is=>'ro', isa=>'SafeStore'            , required=>1                                );
    has 'commited'        => ( is=>'rw', isa=>'Bool'                 , default=>0                                 );
    has 'remove_data'     => ( is=>'rw', isa=>'ArrayRef[Str]'        , default=>sub { return [ ] }                );
    #~ ---------------- ~#
    sub set( $self, $key, $value )
    {
        SafeStore::Error::StoreCommited->raise( "Can't set" ) if $self->commited;
    
        $self->edit_time( DateTime->now.'' );

        $self->data( { %{ $self->data }, $key => $value } );

        return $self;
    }

    sub remove( $self, $key )
    {
        SafeStore::Error::StoreCommited->raise( "Can't remove" ) if $self->commited;
    
        $self->edit_time( DateTime->now.'' );

        $self->remove_data( [ @{ $self->remove_data }, $key ] );

        return $self;
    }


    sub commit( $self )
    {
        SafeStore::Error::StoreCommited->raise( "Can't commit" ) if $self->commited;

        $self->master->commit( $self->id );
    }

    sub pack( $self )
    {
        my $packed = { %$self };

        delete $packed->{master};

        return $packed;
    }
};
1;