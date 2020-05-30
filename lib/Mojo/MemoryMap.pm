package Mojo::MemoryMap;
use Mojo::Base -base;

use File::Map qw(map_anonymous);
use Mojo::File qw(tempfile);
use Mojo::MemoryMap::Writer;

sub new {
  my ($class, $size) = @_;
  my $self = $class->SUPER::new(size => $size // 52428800, usage => 0);

  $self->{tempfile} = tempfile->touch;
  map_anonymous my $map, $self->{size}, 'shared';
  $self->{map} = \$map;
  $self->writer->store({});

  return $self;
}

sub size { shift->{size} }

sub usage { shift->{usage} }

sub writer {
  my $self = shift;

  my $fh = $self->{fh}{$$} ||= $self->{tempfile}->open('>');
  return Mojo::MemoryMap::Writer->new(fh => $fh, map => $self->{map}, usage => \$self->{usage});
}

1;

=encoding utf8

=head1 NAME

Mojo::MemoryMap - Safely use anonymous memory mapped segments

=head1 SYNOPSIS

  use Mojo::MemoryMap;

  my $map = Mojo::MemoryMap->new(4096);
  say $map->usage;
  $map->writer->store({foo => 123});
  say $map->writer->fetch->{foo};
  say $map->writer->change(sub { delete $_->{foo} });
  say $map->usage;

=head1 DESCRIPTION

L<Mojo::MemoryMap> uses L<File::Map> to allow you to safely cache mutable data structures in anonymous mapped memory
segments, and share it between multiple processes.

=head1 METHODS

L<Mojo::MemoryMap> inherits all methods from L<Mojo::Base> and implements the following new ones.

=head2 new

  my $map = Mojo::MemoryMap->new;
  my $map = Mojo::MemoryMap->new(4096);

Construct a new L<Mojo::MemoryMap> object, defaults to a L</"size"> of C<52428800> bytes (50 MiB).

=head2 size

  my $size = $map->size;

Size of anonymous memory segment in bytes.

=head2 usage

  my $usage = $map->usage;

Current usage of anonymous memory segment in bytes.

=head2 writer

  my $writer = $map->writer;

Acquire exclusive lock and return L<Mojo::MemoryMap::Writer> object. Allowing the shared data structure to be retrieved
and modified safely. The lock is released when the writer object is destroyed.

  # Retrieve data
  my $data = $map->writer->fetch;

  # Modify data safely
  my $writer = $map->writer;
  my $data = $writer->fetch;
  $data->{foo} += 23;
  $writer->store($data);
  undef $writer;

  # Modify data safely (with less code)
  $map->writer->change(sub { $_->{foo} += 23 });

=head1 SEE ALSO

L<Mojolicious::Plugin::Status>, L<Mojolicious::Guides>, L<https://mojolicious.org>.

=cut
