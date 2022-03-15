package SafeStore::Class;
{
    use Moose;
    use MooseX::Storage;
 
    with Storage('format' => 'JSON', 'io' => 'File');
};
1;