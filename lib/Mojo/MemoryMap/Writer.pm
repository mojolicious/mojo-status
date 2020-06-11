package Mojo::MemoryMap::Writer;
use Mojo::Base -base;

use Fcntl qw(:flock);
use Cpanel::JSON::XS;

my $JSON = Cpanel::JSON::XS->new->utf8;

sub DESTROY { flock(shift->{fh}, LOCK_UN) or die "Couldn't flock: $!" }

sub change {
  my ($self, $cb) = @_;
  my $stats = $self->fetch;
  $cb->($_) for $stats;
  return $self->store($stats);
}

sub fetch {
  my $self = shift;
  my $len  = unpack 'N', substr(${$self->{map}}, 0, 4);
  return $JSON->decode(substr(${$self->{map}}, 4, $len));
}

sub new {
  my $self = shift->SUPER::new(@_);
  flock($self->{fh}, LOCK_EX) or die "Couldn't flock: $!";
  return $self;
}

sub store {
  my ($self, $data) = @_;

  my $json  = $JSON->encode($data);
  my $bytes = pack('N', length $json) . $json;

  ${$self->{usage}} = my $usage = length $bytes;
  return undef if $usage > length ${$self->{map}};
  substr ${$self->{map}}, 0, $usage, $bytes;

  return 1;
}

1;

=encoding utf8

=head1 NAME

Mojo::MemoryMap::Writer - Writer

=head1 SYNOPSIS

  use Mojo::MemoryMap::Writer;

  my $writer = Mojo::MemoryMap::Writer->new(map => $map);
  $writer->store({foo => 123});
  say $writer->fetch->{foo};

=head1 DESCRIPTION

L<Mojo::MemoryMap::Writer> is a scope guard for L<Mojo::MemoryMap> that allows you to write safely to anonymous mapped
memory segments.

=head1 METHODS

L<Mojo::MemoryMap::Writer> inherits all methods from L<Mojo::Base> and implements the following new ones.

=head2 change

  my $bool = $writer->change(sub {...});

Fetch data, modify it in the closure and store it again right away.

  # Remove a value safely
  $writer->change(sub { delete $_->{foo} });

=head2 fetch

  my $data = $writer->fetch;

Fetch data.

=head2 new

  my $writer = Mojo::MemoryMap::Writer->new;
  my $writer = Mojo::MemoryMap::Writer->new(map => $map);
  my $writer = Mojo::MemoryMap::Writer->new({map => $map});

Construct a new L<Mojo::MemoryMap::Writer> object.

=head2 store

  my $bool = $writer->store({foo => 123});

Store data, replacing all existing data.

=head1 SEE ALSO

L<Mojolicious::Plugin::Status>, L<Mojolicious::Guides>, L<https://mojolicious.org>.

=cut
