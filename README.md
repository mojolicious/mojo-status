
# Mojolicious-Plugin-Status [![](https://github.com/mojolicious/mojo-status/workflows/linux/badge.svg)](https://github.com/mojolicious/mojo-status/actions)

![Screenshot](https://raw.github.com/mojolicious/mojo-status/main/examples/status.png?raw=true)

  A server status ui for the [Mojolicious](https://mojolicious.org) real-time web framework. Note that this module is
  **EXPERIMENTAL** and should therefore only be used for debugging purposes.

```perl
use Mojolicious::Lite;

plugin 'Status';

app->start;
```

## Installation

  All you need is a one-liner, it takes less than a minute.

    $ curl -L https://cpanmin.us | perl - -M https://cpan.metacpan.org -n Mojolicious::Plugin::Status

  We recommend the use of a [Perlbrew](http://perlbrew.pl) environment.

## Want to know more?

  Take a look at our excellent
  [documentation](https://mojolicious.org/perldoc/Mojolicious/Plugin/Status)!
