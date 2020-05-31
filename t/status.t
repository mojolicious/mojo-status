use Mojo::Base -strict;

use Test::More;
use Config;
use Mojolicious::Lite;
use Mojo::IOLoop;
use Test::Mojo;

my $route = any '/status';

plugin Status => {return_to => '/does_not_exist', route => $route, slowest => 5};

get '/' => sub {
  my $c = shift;
  $c->render(text => 'Hello Mojo!');
};

get '/subprocess' => sub {
  my $c = shift;

  $c->inactivity_timeout(3600);

  Mojo::IOLoop->subprocess(
    sub {
      return $$;
    },
    sub {
      my ($subprocess, $err, $pid) = @_;
      $c->render(text => $pid);
    }
  );
};

my $t = Test::Mojo->new;

subtest 'Basics' => sub {
  $t->get_ok('/status.json')->status_is(200)->json_is('/processed', 0);
  $t->get_ok('/')->status_is(200)->content_is('Hello Mojo!');
  $t->get_ok('/status.json')->status_is(200)->json_is('/processed', 4);
};

subtest 'Bundled static files' => sub {
  $t->get_ok('/mojo-status/bootstrap/bootstrap.js')->status_is(200)->content_type_is('application/javascript');
  $t->get_ok('/mojo-status/bootstrap/bootstrap.css')->status_is(200)->content_type_is('text/css');
  $t->get_ok('/mojo-status/fontawesome/fontawesome.css')->status_is(200)->content_type_is('text/css');
  $t->get_ok('/mojo-status/webfonts/fa-brands-400.eot')->status_is(200);
  $t->get_ok('/mojo-status/webfonts/fa-brands-400.svg')->status_is(200);
  $t->get_ok('/mojo-status/webfonts/fa-brands-400.ttf')->status_is(200);
  $t->get_ok('/mojo-status/webfonts/fa-brands-400.woff')->status_is(200);
  $t->get_ok('/mojo-status/webfonts/fa-brands-400.woff2')->status_is(200);
  $t->get_ok('/mojo-status/webfonts/fa-regular-400.eot')->status_is(200);
  $t->get_ok('/mojo-status/webfonts/fa-regular-400.svg')->status_is(200);
  $t->get_ok('/mojo-status/webfonts/fa-regular-400.ttf')->status_is(200);
  $t->get_ok('/mojo-status/webfonts/fa-regular-400.woff')->status_is(200);
  $t->get_ok('/mojo-status/webfonts/fa-regular-400.woff2')->status_is(200);
  $t->get_ok('/mojo-status/webfonts/fa-solid-900.eot')->status_is(200);
  $t->get_ok('/mojo-status/webfonts/fa-solid-900.svg')->status_is(200);
  $t->get_ok('/mojo-status/webfonts/fa-solid-900.ttf')->status_is(200);
  $t->get_ok('/mojo-status/webfonts/fa-solid-900.woff')->status_is(200);
  $t->get_ok('/mojo-status/webfonts/fa-solid-900.woff2')->status_is(200);
  $t->get_ok('/mojo-status/app.css')->status_is(200)->content_type_is('text/css');
  $t->get_ok('/mojo-status/logo-black-2x.png')->status_is(200)->content_type_is('image/png');
  $t->get_ok('/mojo-status/logo-black.png')->status_is(200)->content_type_is('image/png');
};

subtest 'JSON' => sub {
  $t->get_ok('/status.json')->status_is(200)->json_is('/processed', 48)->json_has('/started')
    ->json_has("/workers/$$/connections")->json_has("/workers/$$/maxrss")->json_has("/workers/$$/processed")
    ->json_has("/workers/$$/started")->json_has("/workers/$$/stime")->json_has("/workers/$$/utime")
    ->json_has('/slowest/0')->json_has('/slowest/0/time')->json_has('/slowest/0/path')
    ->json_has('/slowest/0/request_id')->json_has('/slowest/1')->json_has('/slowest/4')->json_hasnt('/slowest/5');
};

subtest 'HTML' => sub {
  $t->get_ok('/status')->element_exists_not('meta[http-equiv=refresh][content=5]')
    ->text_like('a[href=/does_not_exist]' => qr/Back to Site/);
};

subtest 'Reset' => sub {
  $t->get_ok('/status.json')->status_is(200)->json_has('/slowest/2');
  $t->get_ok('/status?reset=1')->status_is(302);
  $t->get_ok('/status.json')->status_is(200)->json_hasnt('/slowest/2');
};

SKIP: {
  skip 'Subprocess does not work with fork emulation', 2 if $Config{d_pseudofork};

  subtest 'Subprocess' => sub {
    $t->get_ok('/subprocess')->status_is(200);
    my $pid = $t->tx->res->text;
    $t->get_ok('/status.json')->status_is(200)->json_has('/started')->json_has("/workers/$$")
      ->json_hasnt("/workers/$pid");
  };
}

subtest 'Refresh' => sub {
  $t->get_ok('/status?refresh=5')->element_exists('meta[http-equiv=refresh][content=5]');
};

done_testing;
