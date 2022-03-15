package SafeStore::File;
{
    use Moose;
    use Error;
    use Error::Simple;
    use feature qw( signatures );
    #~ -------------------------------- ~#
    extends 'SafeStore::Class';
    #~ -------------------------------- ~#
    has 'path' => ( is=>'ro', isa=>'Str', required=>1 );
    #~ -------------------------------- ~#
    sub is_exists( $self )
    {
        return -e $self;
    }

    sub create( $self )
    {
        if ( $self->is_exists )
        {
            throw Error::Simple( "$self->path allready exists" );
        } else {
            $self->write( "", '>' );
        }
    }

    sub write( $self, $content, $mode='>>' )
    {
        open( my $FH, $mode, $self->path );

        print( $FH $content );
      
        close( $FH );
    }

    sub create_if_not_exists( $self )
    {
        if ( !$self->is_exists )
        {
            $self->create;
        }
    }

    sub read( $self )
    {
        open( my $FH, '<', $self->path );

        my $content;

        $content .= $_ while <$FH>;
        
        close( $FH );

        return $content;
    }

    sub remove( $self )
    {
        unlink( $self->path );
    }
};
1;