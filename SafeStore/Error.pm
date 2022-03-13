package SafeStore::Error;
{
    use Moose;
    use Error;
    use Error::Simple;
    use MooseX::Storage;
    use feature qw( signatures );
    #~ -------------------------------- ~#
    with Storage('format' => 'JSON', 'io' => 'File');
    #~ -------------------------------- ~#
    extends 'Error::Simple';
    #~ -------------------------------- ~#
    sub raise( $cls, $message )
    {
        throw $cls( $message );
    }
};
1;