use Mojo::Base -strict;

use Test::More;
use Mojolicious::Lite;
use Test::Mojo;

plugin Status => {shm_key => 4321};

get '/' => sub {
  my $c = shift;
  $c->render(text => 'Hello Mojo!');
};

my $t = Test::Mojo->new;
$t->get_ok('/')->status_is(200)->content_is('Hello Mojo!');

$t->get_ok('/mojo-status.json')->json_is('/processed', 4);

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

done_testing;
