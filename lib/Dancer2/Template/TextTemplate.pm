package Dancer2::Template::TextTemplate;
# ABSTRACT: Text::Template engine for Dancer2

use 5.010001;
use strict;
use warnings;
use utf8;

# VERSION

use Carp 'croak';
use Moo;
use Dancer2::Core::Types 'InstanceOf';
use Dancer2::Template::TextTemplate::FakeEngine;
use namespace::clean;

with 'Dancer2::Core::Role::Template';

=head1 SYNOPSIS

To use this engine, you may configure L<Dancer2> via C<config.yml>:

    template: text_template

=head1 DESCRIPTION

This template engine allows you to use L<Text::Template> in L<Dancer2>.

Contrary to other template engines (like L<Template::Toolkit>), where I<one>
instance may work on I<multiple> templates, I<one> L<Text::Template> instance
is created I<for each> template. Therefore, if:

=for :list
* you don't use a huge amount of different templates;
* you don't use each template just once;

then it may be interesting to B<cache> Text::Template instances for later use.

If so, you should specify a B<timeout> after which cached Text::Template
instances are to be refreshed, since you might have changed your template
sources without restarting Dancer2.

To enable caching in your C<config.yml>:

    template: text_template
    engines:
        text_template:
            caching: 1      # default
            expires: 3600   # in seconds; default
                            # (use 0 for no expiration)

=cut

has '+engine' =>
  ( isa => InstanceOf['Dancer2::Template::TextTemplate::FakeEngine'] );

sub _build_engine {
    my $self = shift;
    my $engine = Dancer2::Template::TextTemplate::FakeEngine->new;
    for (qw/ caching expires delimiters cache_stringrefs /) {
        $engine->$_($self->config->{$_}) if $self->config->{$_};
    }
    return $engine;
}

=method render( $template, \%tokens )

Renders the template.

=begin :list

* C<$template> is either a (string) filename for the template file or a
reference to a string that contains the template.

* C<\%tokens> is a hashref for the tokens you wish to pass to
L<Text::Template> for rendering, as if you were using
C<Text::Template::fill_in>.

=end :list

L<Carp|Croak>s if an error occurs.

=cut

sub render {
    my ( $self, $template, $tokens ) = @_;
    return $self->engine->process( $template, $tokens )
      or croak $Dancer2::Template::TextTemplate::FakeEngine::ERROR;
}

1;
