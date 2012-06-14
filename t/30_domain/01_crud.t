#!/usr/bin/perl

use strict;
use warnings;
use Test::More 0.96;
use Test::Exception;

use lib 't/lib';

our $es;
do 'es.pl';

use_ok 'MyApp' || print 'Bail out';

my $model = new_ok( 'MyApp', [ es => $es ], 'Model' );
ok my $ns = $model->namespace('myapp'), 'Got ns';

ok $ns->index('myapp2')->create, 'Create index myapp2';

ok $ns->alias->to('myapp2'), 'Alias myapp to myapp2';
ok $ns->alias('routed')->to( myapp2 => { routing => 'foo' } ),
    'Alias routed to myapp2 with routing';

## Basics - myapp ##
isa_ok my $myapp = $model->domain('myapp'), 'Elastic::Model::Domain',
    'Got domain myapp';
is $myapp->name, 'myapp', 'myapp has name';
is $myapp->namespace->name, 'myapp', 'myapp has namespace:myapp';
ok !$myapp->_default_routing, 'myapp has no default routing';

## Basics - routed ##
isa_ok my $routed = $model->domain('routed'), 'Elastic::Model::Domain',
    'Got domain routed';
is $routed->name, 'routed', 'routed has name';
is $routed->namespace->name, 'myapp', 'routed has namespace:myapp';
is $routed->_default_routing, 'foo', 'routed has default routing';

## new_doc - myapp ##

isa_ok my $user = $myapp->new_doc(
    user => {
        id    => 1,
        name  => 'Clint',
        email => 'clint@foo.com'
    }
    ),
    'MyApp::User', 'User';

## UID pre-save ##
test_uid(
    $user,
    'Pre-save UID',
    {   index      => 'myapp',
        type       => 'user',
        id         => 1,
        routing    => '',
        version    => undef,
        from_store => undef,
        cache_key  => 'user;1'
    }
);

ok $user->save, 'User saved';

test_uid(
    $user,
    'Saved UID',
    {   index      => 'myapp2',
        type       => 'user',
        id         => 1,
        routing    => '',
        version    => 1,
        from_store => 1,
        cache_key  => 'user;1'
    }
);

## create - routed ##
isa_ok $user = $routed->create(
    user => {
        id    => 2,
        name  => 'John',
        email => 'john@foo.com'
    }
    ),
    'MyApp::User', 'Routed user';

## UID post save ##
test_uid(
    $user,
    'Routed UID',
    {   index      => 'myapp2',
        type       => 'user',
        id         => 2,
        routing    => 'foo',
        version    => 1,
        from_store => 1,
        cache_key  => 'user;2'
    }
);

## Get - myapp - user##
isa_ok $user= $myapp->get( user => 1 ), 'MyApp::User', 'Get user myapp';

test_uid(
    $user,
    'Retrieved UID',
    {   index      => 'myapp2',
        type       => 'user',
        id         => 1,
        routing    => '',
        version    => 1,
        from_store => 1,
        cache_key  => 'user;1'
    }
);

throws_ok sub { $myapp->get( user => 2 ) }, qr/Missing/,
    'Myapp without routing';

is $myapp->get( user => 2, routing => 'foo' )->uid->id, 2,
    'Myapp with routing';

## Get - routed ##
isa_ok $user = $routed->get( user => 2 ), 'MyApp::User', 'Get user routed';

test_uid(
    $user,
    'Retrieved routed UID',
    {   index      => 'myapp2',
        type       => 'user',
        id         => 2,
        routing    => 'foo',
        version    => 1,
        from_store => 1,
        cache_key  => 'user;2'
    }
);

throws_ok sub { $routed->get( user => 1 ) }, qr/Missing/,
    'Routed without routing';

## Maybe get ##
isa_ok $user = $routed->get( user => 2 ), 'MyApp::User', 'Maybe_get existing';
is $myapp->maybe_get(user=>3), undef, 'Maybe_get missing';


## Change and save ##
is $user->name('James'), 'James', 'Field updated';
ok $user->save, 'User saved';
test_uid(
    $user,
    'Updated UID',
    {   index      => 'myapp2',
        type       => 'user',
        id         => 2,
        routing    => 'foo',
        version    => 2,
        from_store => 1,
        cache_key  => 'user;2'
    }
);

## DONE ##

done_testing;

sub test_uid {
    my ( $obj, $name, $vals ) = @_;
    isa_ok my $uid = $obj->uid, 'Elastic::Model::UID', $name;
    for my $t (qw(index type id routing version from_store cache_key)) {
        is $uid->$t, $vals->{$t}, "$name $t";
    }
}

__END__