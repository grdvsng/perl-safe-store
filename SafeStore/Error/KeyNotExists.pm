package SafeStore::Error::KeyNotExists;
{
    use Moose;
    use feature qw( signatures );
    #~ ---------------- ~#
    extends 'SafeStore::Error';
    #~ ---------------- ~#
    sub new( $cls, $key )
    {
        my $self = $cls->SUPER::new( "Key '$key' not exists" );

        return $self;
    }
};
1;



