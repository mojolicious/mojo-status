use Mojolicious::Lite -signatures;
use Mojo::EventEmitter;
use Mojo::IOLoop;

plugin 'Status';

helper events => sub { state $events = Mojo::EventEmitter->new };

get '/' => 'dashboard';

get '/slow' => sub ($c) {
  $c->inactivity_timeout(3600);

  Mojo::IOLoop->timer(6 => sub { $c->redirect_to('dashboard') });
};

get '/superslow' => sub ($c) {
  $c->inactivity_timeout(3600);

  Mojo::IOLoop->timer(31 => sub { $c->redirect_to('dashboard') });
};

get '/subprocess' => sub ($c) {
  $c->inactivity_timeout(3600);

  Mojo::IOLoop->subprocess(sub { sleep 3 }, sub { $c->redirect_to('dashboard') });
};

get '/chat';

websocket '/channel' => sub ($c) {
  $c->inactivity_timeout(3600);

  # Forward messages from the browser
  $c->on(message => sub ($c, $message) { $c->events->emit(mojochat => $message) });

  # Forward messages to the browser
  my $cb = $c->events->on(mojochat => sub ($events, $message) { $c->send($message) });
  $c->on(finish => sub ($c, $code, $reason) { $c->events->unsubscribe(mojochat => $cb) });
};

# Minimal single-process WebSocket chat application for browser testing
app->start;
__DATA__

@@ dashboard.html.ep
<%= link_to Chat       => 'chat' %>
<%= link_to Slow       => 'slow' %>
<%= link_to Superslow  => 'superslow' %>
<%= link_to Subprocess => 'subprocess' %>
<%= link_to Status     => 'mojo_status' %>

@@ chat.html.ep
<form onsubmit="sendChat(this.children[0]); return false"><input></form>
<div id="log"></div>
<script>
  var ws  = new WebSocket('<%= url_for('channel')->to_abs %>');
  ws.onmessage = function (e) {
    document.getElementById('log').innerHTML += '<p>' + e.data + '</p>';
  };
  function sendChat(input) { ws.send(input.value); input.value = '' }
</script>
