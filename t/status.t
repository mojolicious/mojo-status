use Mojo::Base -strict;

use Test::More;
use Mojolicious::Lite;
use Test::Mojo;

my $route = any '/status';

plugin Status =>
  {shm_key => 4321, return_to => '/does_not_exist', route => $route};

get '/' => sub {
  my $c = shift;
  $c->render(text => 'Hello Mojo!');
};

my $t = Test::Mojo->new;

# Basics
$t->get_ok('/status.json')->status_is(200)->json_is('/processed', 2);
$t->get_ok('/')->status_is(200)->content_is('Hello Mojo!');
$t->get_ok('/status.json')->status_is(200)->json_is('/processed', 6);

# Bundled static files
$t->get_ok('/mojo-status/bootstrap/bootstrap.js')->status_is(200)
  ->content_type_is('application/javascript');
$t->get_ok('/mojo-status/bootstrap/bootstrap.css')->status_is(200)
  ->content_type_is('text/css');
$t->get_ok('/mojo-status/fontawesome/fontawesome.css')->status_is(200)
  ->content_type_is('text/css');
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
$t->get_ok('/mojo-status/logo-black-2x.png')->status_is(200)
  ->content_type_is('image/png');
$t->get_ok('/mojo-status/logo-black.png')->status_is(200)
  ->content_type_is('image/png');

# JSON
$t->get_ok('/status.json')->status_is(200)->json_is('/processed', 50)
  ->json_has('/started')->json_has("/workers/$$/connections")
  ->json_has("/workers/$$/maxrss")->json_has("/workers/$$/processed")
  ->json_has("/workers/$$/started")->json_has("/workers/$$/stime")
  ->json_has("/workers/$$/utime");

# HTML
$t->get_ok('/status')
  ->element_exists_not('meta[http-equiv=refresh][content=5]')
  ->text_like('a[href=/does_not_exist]' => qr/Back to Site/);

# Refresh
$t->get_ok('/status?refresh=5')
  ->element_exists('meta[http-equiv=refresh][content=5]');

done_testing;
