use 5.010001;

use strict;
use warnings;

use ExtUtils::MakeMaker;

# File::Temp 0.2308+ is required to avoid flock bugs
WriteMakefile(
  NAME         => 'Mojolicious::Plugin::Status',
  VERSION_FROM => 'lib/Mojolicious/Plugin/Status.pm',
  ABSTRACT     => 'Mojolicious server status',
  AUTHOR       => 'Sebastian Riedel <sri@cpan.org>',
  LICENSE      => 'artistic_2',
  META_MERGE   => {
    dynamic_config => 0,
    'meta-spec'    => {version => 2},
    no_index       => {directory => ['t']},
    prereqs        => {runtime => {requires => {perl => '5.010001'}}},
    resources      => {
      bugtracker =>
        {web => 'https://github.com/mojolicious/mojo-status/issues'},
      homepage   => 'https://mojolicious.org',
      license    => ['http://www.opensource.org/licenses/artistic-license-2.0'],
      repository => {
        type => 'git',
        url  => 'https://github.com/mojolicious/mojo-status.git',
        web  => 'https://github.com/mojolicious/mojo-status',
      },
      x_IRC => 'irc://irc.freenode.net/#mojo'
    },
  },
  PREREQ_PM => {
    Mojolicious     => '8.33',
    'BSD::Resource' => 0,
    'File::Map'     => 0,
    'File::Temp'    => '0.2308',
    Sereal          => 0
  },
  test => {TESTS => 't/*.t'}
);
