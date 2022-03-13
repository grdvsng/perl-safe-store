package SafeStore::Error::RollbackIsImpossible;
{
    use Moose;
    use feature qw( signatures );
    #~ ---------------- ~#
    extends 'SafeStore::Error';
    #~ ---------------- ~#
    sub new( $cls, $message )
    {
        my $self = $cls->SUPER::new( "$message" );

        return $self;
    }
};
1;



