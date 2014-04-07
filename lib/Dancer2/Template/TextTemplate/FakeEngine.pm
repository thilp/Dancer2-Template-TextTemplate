package Dancer2::Template::TextTemplate::FakeEngine;
# ABSTRACT: Fake Template::Toolkit-like, persistent engine around Text::Template.

use 5.010001;
use strict;
use warnings;
use utf8;

# VERSION

use Moo;
use MooX::Types::MooseLike::Base qw( Bool ArrayRef Int Str );
use Carp 'croak';
use Text::Template;
use CHI;
use Scalar::Util 'blessed';
use namespace::clean;

=head1 SYNOPSIS

=head1 DESCRIPTION

With L<Template::Toolkit>-like engines, you instanciate I<one> engine to
process I<multiple> templates.
With L<Text::Template>, you instanciate I<one> engine to process I<one>
template.
This class is a simple wrapper around Text::Template to simplify its use as a
template engine in L<Dancer2>. It basically just manage Text::Template
instances (and their expiration) through L<CHI>.

=cut

=comment

This is our cache. We should gather CHI-related options from config.yml to
support other caching methods like Memcached. That sounds overkill to me, but
an open interface is always better than a predefined one!

=cut

has _cache => (
    is      => 'rwp',
    isa     => 'CHI::Driver',
    lazy    => 1,
    builder => 1,
);

sub _build_cache {
    my $self = shift;
    return CHI->new(
        driver             => 'Memory',    # THIS should be generalized
        expires_on_backend => 1,
        expires_in => $self->expires > 0 ? $self->expires : 'never',
    );
}

=attr caching

Whether a cache should be used for storing Text::Template instances, or not.

Defaults to C<1> (caching enabled).

=cut

has caching => (
    is      => 'rw',
    isa     => Bool,
    default => 1,
);

=attr expires

How longer (in seconds) the a Text::Template instance will stay in the cache.
After this duration, when the corresponding template is requested again, a new
Text::Template instance will be created (and cached).

Defaults to C<3600> (one hour).
Obviously irrelevant if C<caching> is set to C<0>!

=cut

has expires => (
    is      => 'rw',
    isa     => Int,
    default => 3600,
);

=attr delimiters

An arrayref of (two) delimiters, as defined in L<Text::Template#new>.

Defaults to C<< [ '{', '}' ] >>.

=cut

has delimiters => (
    is      => 'rw',
    isa     => ArrayRef [Str],
    default => sub { [ '{', '}' ] },
);

=method process( $template, \%tokens )

Computes the C<$template> according to specified C<\%tokens>.

If C<$template> is a string, it is taken as a filename for the template file
(if this file does not exist, the method C<croak>s). If C<$template> is a
scalar reference, it is taken as a reference to a string that contains the
template. In any other case, this method will C<croak> furiously.

Note that, if C<caching> is true, (dereferenced) string references will be
cached too.

This methods simply gets a Text::Template instance (either from cache or by
instanciating it) and calls C<< Text::Template::fill_in( HASH => \%tokens ) >>
on it, returning the result.

If an error occurs in Text::Template, this method returns C<undef>, sets
C<Dancer2::Template::TextTemplate::FakeEngine::ERROR> to the value of
C<Text::Template::ERROR> and does not cache anything.

=cut

sub process {
    my ( $self, $template, $tokens ) = @_;

    defined $template
      && !blessed($template)
      && ( ref $template || -f $template )
      or croak "$template is not a regular file (name) or a string reference";

    my $tt = $self->caching
      ? $self->_cache->get( ref $template ? $$template : $template )
      : undef;
    unless ($tt) {    # either we don't cache or the cached instance expired
        $tt = Text::Template->new(
            TYPE   => ref $template ? 'STRING'   : 'FILE',
            SOURCE => ref $template ? $$template : $template,
            DELIMITERS => $self->delimiters,
        );
    }

    my $computed = $tt->fill_in( HASH => $tokens )
      or our $ERROR = $Text::Template::ERROR;

    if ( $computed && $self->caching ) {
        $self->_cache->set( ref $template ? $$template : $template, $tt );
    }

    return $computed;
}

1;
