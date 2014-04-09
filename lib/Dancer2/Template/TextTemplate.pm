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

B<This is an alpha version: it basically works, but it has not been
extensively tested and it misses interesting features.>

This template engine allows you to use L<Text::Template> in L<Dancer2>.

=head2 Configuration

Here are all available options, as you would set them in a C<config.yml>, with
their B<default> values:

    template: text_template
    engines:
        text_template:
            caching: 1
            expires: 3600               # in seconds; use 0 to disable
            cache_stringrefs: 1
            delimiters: [ "{", "}" ]
            prepend: |
                use strict;
                use warnings;
            safe: 0                     # currently a no-op

The following sections explain what these options do.

=head2 Global caching - C<caching>, C<expires>

Contrary to other template engines (like L<Template::Toolkit>), where I<one>
instance may work on I<multiple> templates, I<one> L<Text::Template> instance
is created I<for each> template. Therefore, if:

=for :list
* you don't use a huge amount of different templates;
* you don't use each template just once;

then it may be interesting to B<cache> Text::Template instances for later use.
Since these conditions seem to be common, this engine uses a cache (I<via>
L<CHI>) B<by default>.

If you're OK with caching, you should specify a B<timeout> (C<expires>) after
which cached Text::Template instances are to be refreshed, since you might
have changed your template sources without restarting Dancer2. By default,
this engine uses C<expires: 3600> (one hour). Use C<0> to tell it that
templates never expire.

If you don't want any caching, just set C<caching> to C<0>.

=head2 "String-ref templates" caching - C<cache_stringrefs>

Just like with L<Dancer2::Template::Toolkit>, you can pass templates either as
filenames (for a template file) or string references ("string-refs", which are
dereferenced and used as the template's content). In some cases, you may want
to disable caching for string-refs only: for instance, if you generate a lot
of templates on-the-fly and use them only once, caching them is useless and
fills your cache. You can therefore disable caching I<for string-refs only> by
setting C<cache_stringrefs> to C<0>.

Note that if you set C<caching> to C<0>, you don't have I<any> caching, so
C<cache_stringrefs> is ignored.

=head2 Custom delimiters - C<delimiters>

The C<delimiters> option allows you to specify a custom delimiters pair
(opening and closing) for your templates. See the L<Text::Template>
documentation for more about delimiters, since this module just pass them to
Text::Template. This option defaults to C<{> and C<}>, meaning that in C<< a
{b} c >>, C<b> (and only C<b>) will be interpolated.

=head2 Prepending code - C<prepend>

This option specifies Perl code run by Text::Template I<before> evaluating
each template. For instance, with this option's default value, i.e.:

    use strict;
    use warnings FATAL => 'all';

then evaluating the following template:

    you're the { $a + 1 }th visitor!

is the same as evaluating:

    {
        use strict;
        use warnings FATAL => 'all';
        ""
    }you're the { $a + 1 }th visitor!

and thus you get:

    Program fragment delivered error
    ``Use of uninitialized value $a in addition (+) [...]

in your template output if you forgot to pass a value for C<$a>.

If you don't want anything prepended to your templates, simply give a
non-dying, side-effects-free Perl expression to C<prepend>, like C<0> or
C<"">.

=head2 Running in a L<Safe> - C<safe>

Not yet implemented!

=cut

has '+engine' =>
  ( isa => InstanceOf['Dancer2::Template::TextTemplate::FakeEngine'] );

sub _build_engine {
    my $self = shift;
    my $engine = Dancer2::Template::TextTemplate::FakeEngine->new;
    for (qw/ caching expires delimiters cache_stringrefs prepend /) {
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
    $self->engine->process( $template, $tokens )
      or croak $Dancer2::Template::TextTemplate::FakeEngine::ERROR;
}

1;
