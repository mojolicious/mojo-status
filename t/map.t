use Mojo::Base -strict;

use Test::More;
use Mojo::MemoryMap;

# Basics
my $map = Mojo::MemoryMap->new;
is_deeply $map->writer->fetch, {}, 'empty hash';
ok $map->writer->store({foo => 123}), 'written';
is_deeply $map->writer->fetch, {foo => 123}, 'data retained';
ok $map->writer->change(sub { $_->{foo} += 1 }), 'written';
is_deeply $map->writer->fetch, {foo => 124}, 'data modified';
is $map->size, 52428800, 'right default size';
ok $map->usage > 0, 'has usage';
ok $map->usage < $map->size, 'size not exceeded';

# Small limit
$map = Mojo::MemoryMap->new(256);
ok $map->writer->store({foo => 'test'}), 'written';
is_deeply $map->writer->fetch, {foo => 'test'}, 'data retained';
ok !$map->writer->store({foo => join('', 1 .. 1000000)}), 'not written';
is_deeply $map->writer->fetch, {foo => 'test'}, 'data unmodified';
ok $map->writer->store({foo => 'works'}), 'written';
is_deeply $map->writer->fetch, {foo => 'works'}, 'data retained';
is $map->size, 256, 'right size';

done_testing;
