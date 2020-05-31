package Mojolicious::Plugin::Status;
use Mojo::Base 'Mojolicious::Plugin';

use BSD::Resource qw(getrusage);
use Time::HiRes qw(time);
use Mojo::File qw(path);
use Mojo::IOLoop;
use Mojo::MemoryMap;
use Mojo::Util qw(humanize_bytes);

use constant MACOS => $^O eq 'darwin';

our $VERSION = '1.12';

sub register {
  my ($self, $app, $config) = @_;

  # Config
  my $prefix = $config->{route} // $app->routes->any('/mojo-status');
  $prefix->to(return_to => $config->{return_to} // '/');
  $self->{slowest} = $config->{slowest} // 10;

  # Initialize cache
  my $map = $self->{map} = Mojo::MemoryMap->new($config->{size});
  $map->writer->store({processed => 0, started => time, stats => _stats(), slowest => []});

  # Only the two built-in servers are supported for now
  $app->hook(before_server_start => sub { $self->_start(@_) });

  # Static files
  my $resources = path(__FILE__)->sibling('resources');
  push @{$app->static->paths}, $resources->child('public')->to_string;

  # Templates
  push @{$app->renderer->paths}, $resources->child('templates')->to_string;

  # Routes
  $prefix->get('/' => {mojo_status => $self} => \&_dashboard)->name('mojo_status');
}

sub _activity {
  my $all = shift;

  # Workers
  my @table;
  for my $pid (sort keys %{$all->{workers}}) {
    my $worker = $all->{workers}{$pid};
    my $cpu    = sprintf '%.2f', $worker->{utime} + $worker->{stime};
    my @worker = ($pid, $cpu, humanize_bytes($worker->{maxrss}));

    # Connections
    my $connections = $worker->{connections};
    if (keys %$connections) {
      my $repeat;
      for my $cid (sort keys %$connections) {
        my $conn = $connections->{$cid};
        @worker = ('', '', '') if $repeat++;
        my $bytes_read    = humanize_bytes $conn->{bytes_read};
        my $bytes_written = humanize_bytes $conn->{bytes_written};
        my $rw            = "$bytes_read/$bytes_written";
        my @conn          = ($conn->{client}, $rw, $conn->{processed});

        # Request
        if (my $req = $conn->{request}) {
          my $active = $req->{finished} ? 0 : 1;
          my ($rid, $proto) = @{$req}{qw(request_id protocol)};

          my $str = "$req->{method} $req->{path}";
          $str .= "?$req->{query}"      if $req->{query};
          $str .= " → $req->{status}" if $req->{status};

          my $finished = $active ? time : $req->{finished};
          my $time     = sprintf '%.2f', $finished - $req->{started};
          push @table, [@worker, @conn, $rid, $active, $time, $proto, $str];
        }
        else { push @table, [@worker, @conn] }
      }
    }
    else { push @table, \@worker }
  }

  return \@table;
}

sub _dashboard {
  my $c = shift;

  my $map = $c->stash('mojo_status')->{map};
  if ($c->param('reset')) {
    $map->writer->change(sub { @{$_}{qw(slowest stats)} = ([], _stats()) });
    return $c->redirect_to('mojo_status');
  }

  my $all = $map->writer->fetch;
  $c->respond_to(
    html => sub {
      $c->render(
        'mojo-status/dashboard',
        now      => time,
        usage    => humanize_bytes($map->usage),
        size     => humanize_bytes($map->size),
        activity => _activity($all),
        slowest  => _slowest($all),
        all      => $all
      );
    },
    json => {json => $all}
  );
}

sub _read_write {
  my ($record, $id) = @_;
  return unless my $stream = Mojo::IOLoop->stream($id);
  @{$record}{qw(bytes_read bytes_written)} = ($stream->bytes_read, $stream->bytes_written);
}

sub _request {
  my ($self, $c) = @_;

  # Request start
  my $tx    = $c->tx;
  my $id    = $tx->connection;
  my $req   = $tx->req;
  my $url   = $req->url->to_abs;
  my $proto = $tx->is_websocket ? 'ws' : 'http';
  $proto .= 's' if $req->is_secure;
  $self->{map}->writer->change(sub {
    $_->{workers}{$$}{connections}{$id}{request} = {
      request_id => $req->request_id,
      method     => $req->method,
      protocol   => $proto,
      path       => $url->path->to_abs_string,
      query      => $url->query->to_string,
      started    => time
    };
    _read_write($_->{workers}{$$}{connections}{$id}, $id);
    $_->{workers}{$$}{connections}{$id}{client} = $tx->remote_address;
  });

  # Request end
  $tx->on(
    finish => sub {
      my $tx = shift;
      $self->{map}->writer->change(sub {
        return unless my $worker = $_->{workers}{$$};

        my $code = $tx->res->code || 0;
        if    ($code > 499) { $_->{stats}{server_error}++ }
        elsif ($code > 399) { $_->{stats}{client_error}++ }
        elsif ($code > 299) { $_->{stats}{redirect}++ }
        elsif ($code > 199) { $_->{stats}{success}++ }
        elsif ($code)       { $_->{stats}{info}++ }

        $worker->{connections}{$id}{request}{finished} = time;
        $worker->{connections}{$id}{request}{status}   = $code;
        $worker->{connections}{$id}{processed}++;
        $worker->{processed}++;
        $_->{processed}++;
      });
    }
  );
}

sub _rendered {
  my ($self, $c) = @_;

  my $id   = $c->tx->connection;
  my $map  = $self->{map};
  my $conn = $map->writer->fetch->{workers}{$$}{connections}{$id};
  return unless $conn && (my $req = $conn->{request});
  $req->{time} = time - $req->{started};
  @{$req}{qw(client status worker)} = ($conn->{client}, $c->res->code, $$);

  $map->writer->change(sub {
    my $slowest = $_->{slowest};
    @$slowest = sort { $b->{time} <=> $a->{time} } @$slowest, $req;
    my %seen;
    @$slowest = grep { !$seen{"$_->{method} $_->{path}"}++ } @$slowest;
    pop @$slowest while @$slowest > $self->{slowest};
  });
}

sub _resources {
  my $self = shift;

  $self->{map}->writer->change(sub {
    @{$_->{workers}{$$}}{qw(utime stime maxrss)} = (getrusage)[0, 1, 2];

    # macOS actually returns bytes instead of kilobytes
    $_->{workers}{$$}{maxrss} = $_->{workers}{$$}{maxrss} * 1000 unless MACOS;

    for my $id (keys %{$_->{workers}{$$}{connections}}) {
      _read_write($_->{workers}{$$}{connections}{$id}, $id);
    }
  });
}

sub _slowest {
  my $all = shift;

  my @table;
  for my $req (@{$all->{slowest}}) {
    my $str = "$req->{method} $req->{path}";
    $str .= "?$req->{query}"      if $req->{query};
    $str .= " → $req->{status}" if $req->{status};
    my $time = sprintf '%.2f', $req->{time};
    push @table, [$time, $str, @{$req}{qw(request_id worker client started)}];
  }

  return \@table;
}

sub _start {
  my ($self, $server, $app) = @_;
  return unless $server->isa('Mojo::Server::Daemon');

  # Register started workers
  Mojo::IOLoop->next_tick(sub {
    $self->{map}->writer->change(sub { $_->{workers}{$$} = {started => time, processed => 0} });
  });

  # Remove stopped workers
  $server->on(
    reap => sub {
      my ($server, $pid) = @_;
      $self->{map}->writer->change(sub { delete $_->{workers}{$pid} });
    }
  ) if $server->isa('Mojo::Server::Prefork');

  # Collect stats
  $app->hook(after_build_tx  => sub { $self->_tx(@_) });
  $app->hook(before_dispatch => sub { $self->_request(@_) });
  $app->hook(after_dispatch  => sub { $self->_rendered(@_) });
  Mojo::IOLoop->next_tick(sub { $self->_resources });
  Mojo::IOLoop->recurring(5 => sub { $self->_resources });
}

sub _stats {
  return {started => time, info => 0, success => 0, redirect => 0, client_error => 0, server_error => 0};
}

sub _stream {
  my ($self, $id) = @_;

  my $stream = Mojo::IOLoop->stream($id);
  $stream->on(
    close => sub {
      $self->{map}->writer->change(sub { delete $_->{workers}{$$}{connections}{$id} if $_->{workers}{$$} });
    }
  );
}

sub _tx {
  my ($self, $tx, $app) = @_;

  $tx->on(
    connection => sub {
      my ($tx, $id) = @_;

      my $map = $self->{map};
      return if $map->writer->fetch->{workers}{$$}{connections}{$id};

      $map->writer->change(sub {
        $_->{workers}{$$}{connections}{$id} = {started => time, processed => 0, bytes_read => 0, bytes_written => 0};
      });
      $self->_stream($id);
    }
  );
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Status - Mojolicious server status

=head1 SYNOPSIS

  # Mojolicious
  $self->plugin('Status');

  # Mojolicious::Lite
  plugin 'Status';

  # Secure access to the server status ui with Basic authentication
  my $under = $self->routes->under('/status' => sub {
    my $c = shift;
    return 1 if $c->req->url->to_abs->userinfo eq 'Bender:rocks';
    $c->res->headers->www_authenticate('Basic');
    $c->render(text => 'Authentication required!', status => 401);
    return undef;
  });
  $self->plugin('Status' => {route => $under});

=head1 DESCRIPTION

=begin html

<p>
  <img alt="Screenshot" src="https://raw.github.com/mojolicious/mojo-status/master/examples/status.png?raw=true"
    width="600px">
</p>

=end html

L<Mojolicious::Plugin::Status> is a L<Mojolicious> plugin providing a server status ui for L<Mojo::Server::Daemon> and
L<Mojo::Server::Prefork>. Note that this module is B<EXPERIMENTAL> and should therefore only be used for debugging
purposes.

=head1 OPTIONS

L<Mojolicious::Plugin::Status> supports the following options.

=head2 return_to

  # Mojolicious::Lite
  plugin Status => {return_to => 'some_route'};

Name of route or path to return to when leaving the server status ui, defaults to C</>.

=head2 route

  # Mojolicious::Lite
  plugin Status => {route => app->routes->any('/status')};

L<Mojolicious::Routes::Route> object to attach the server status ui to, defaults to generating a new one with the
prefix C</mojo-status>.

=head2 size

  # Mojolicious::Lite
  plugin Status => {size => 1234};

Size of anonymous mapped memory to use for storing statistics, defaults to C<52428800> (50 MiB).

=head2 slowest

  # Mojolicious::Lite
  plugin Status => {slowest => 5}; 

Number of slowest requests to track, defaults to C<10>.

=head1 METHODS

L<Mojolicious::Plugin::Status> inherits all methods from L<Mojolicious::Plugin> and implements the following new ones.

=head2 register

  my $route = $plugin->register(Mojolicious->new);

Register renderer and helper in L<Mojolicious> application.

=head1 BUNDLED FILES

The L<Mojolicious::Plugin::Status> distribution includes a few files with different licenses that have been bundled for
internal use.

=head2 Artwork

  Copyright (C) 2018, Sebastian Riedel.

Licensed under the CC-SA License, Version 4.0 L<http://creativecommons.org/licenses/by-sa/4.0>.

=head2 Bootstrap

  Copyright (C) 2011-2018 The Bootstrap Authors.

Licensed under the MIT License, L<http://creativecommons.org/licenses/MIT>.

=head2 Font Awesome

  Copyright (C) Dave Gandy.

Licensed under the MIT License, L<http://creativecommons.org/licenses/MIT>, and the SIL OFL 1.1,
L<http://scripts.sil.org/OFL>.

=head1 AUTHOR

Sebastian Riedel, C<sri@cpan.org>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018-2020, Sebastian Riedel and others.

This program is free software, you can redistribute it and/or modify it under the terms of the Artistic License version
2.0.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<https://mojolicious.org>.

=cut
