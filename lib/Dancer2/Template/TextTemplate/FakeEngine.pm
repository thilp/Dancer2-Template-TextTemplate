package Dancer2::Template::TextTemplate::FakeEngine;
# ABSTRACT: Fake Template::Toolkit-like, persistent engine around Text::Template.

use strict;
use warnings;

# VERSION

use Moo;
use MooX::Types::MooseLike::Base qw( InstanceOf Bool ArrayRef Int Str );
use Carp 'croak';
use Text::Template 1.46;
use CHI;
use Safe 2.26;
use Scalar::Util 'blessed';
use namespace::clean;

=head1 SYNOPSIS

=head1 DESCRIPTION

With L<Template::Toolkit>-like engines, you instantiate I<one> engine to
process I<multiple> templates.
With L<Text::Template>, you instantiate I<one> engine to process I<one>
template.
This class is a simple wrapper around Text::Template to simplify its use as a
template engine in L<Dancer2>. It basically just manage Text::Template
instances (and their expiration) through L<CHI>.

You can give this engine templates as filenames or string references:

=for :list
* with a filename, the corresponding file will be read by L<Text::Template>;
* a string ref will be dereferenced and its content used as the template
  content itself.

=cut

=for :comment

This is our cache. We should gather CHI-related options from config.yml to
support other caching methods like Memcached. That sounds overkill to me, but
an open interface is always better than a predefined one!

=cut

has _cache => (
    is      => 'rwp',
    isa     => InstanceOf['CHI::Driver'],
    lazy    => 1,
    builder => '_build_cache',
);

sub _build_cache {
    my $self = shift;
    return CHI->new(
        driver             => 'Memory',    # THIS should be generalized
        expires_on_backend => 1,
        global             => 1,           # CHI::Driver::Memory-specific
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
    isa     => ArrayRef[Str],
    default => sub { [ '{', '}' ] },
);

=attr cache_stringrefs

If this attribute and C<caching> are true (which is the default),
string-ref-templates will always be cached forever (since they cannot become
I<invalid>, contrary to template files that can be changed on disc when
FakeEngine doesn't watch).

However, you may want to disable this behavior for string-ref-templates if you
use a lot of such templates only once (they would fill your cache). By setting
C<cache_stringrefs> to C<0>, you tell FakeEngine not to cache (at all) your
string-ref-templates.

=cut

has cache_stringrefs => (
    is      => 'rw',
    isa     => Bool,
    default => 1,
);

=attr prepend

Contains the string of Perl code added at the top of each evaluated template.
See L<PREPEND in
Text::Template|https://metacpan.org/pod/Text::Template#PREPEND-feature-and-using-strict-in-templates>.

=cut

has prepend => (
    is => 'rw',
    isa => Str,
    default => <<'END',
        use strict;
        use warnings FATAL => 'all';
END
);

# Text::Template's HASH variables (as exclusively used by FakeEngine) are not
# installed in the template evaluation package in a "use strict"-compatible
# way, but we enforce "use strict" in PREPEND, so we need to declare ourselves
# these variables just after the PREPENDed code.
sub _declare_arg_variables {
    my $hash = shift;
    my @decls;
    while ( my ( $name, $value ) = each %$hash ) {
        next unless defined $value;
        push @decls, do {
            if    ( ref $value eq 'ARRAY' ) { '@' }
            elsif ( ref $value eq 'HASH' )  { '%' }
            else                            { '$' }
          }
          . $name;
    }
    return join "\n" => map { "our $_;" } @decls;
}

=attr safe, safe_opcodes, safe_disposable

These attributes are directly linked to the eponymous options in
L<Dancer2::Template::TextTemplate>.

=cut

has safe => (
    is      => 'rw',
    isa     => Bool,
    default => 1,
);

has safe_opcodes => (
    is      => 'rw',
    isa     => ArrayRef[Str],
    default => sub { [qw[ :default require caller dofile ]] },
    trigger => sub {
        my $self = shift;
        $self->_safe->permit_only(@{ $_[0] });
    },
);

has safe_disposable => (
    is      => 'rw',
    isa     => Bool,
    default => 0,
    trigger => sub {
        my $self = shift;
        $self->_rebuild_safe if $_[0];
    },
);

has _safe => (
    is      => 'rw',
    isa     => InstanceOf['Safe'],
    lazy    => 1,
    builder => '_build_safe',
);

sub _build_safe {
    my $self = shift;
    my $safe = Safe->new;
    $safe->permit_only(@{ $self->safe_opcodes });
    return $safe;
}

sub _rebuild_safe {
    my $self = shift;
    $self->_safe($self->_build_safe) if $self->safe_disposable;
    return;
}

=method process( $template, \%tokens )

Computes the C<$template> according to specified C<\%tokens>.

If C<$template> is a string, it is taken as a filename for the template file
(if this file does not exist, the method C<croak>s). If C<$template> is a
scalar reference, it is taken as a reference to a string that contains the
template. In any other case, this method will C<croak> furiously.

Note that, if C<caching> is true, (dereferenced) string references will be
cached too.

This methods simply gets a Text::Template instance (either from cache or by
instantiating it) and calls C<< Text::Template::fill_in( HASH => \%tokens ) >>
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

    my $computed = $tt->fill_in(
        HASH    => $tokens,
        PREPEND => $self->prepend . _declare_arg_variables($tokens),
        $self->safe ? ( SAFE => $self->_safe ) : (),
    ) or our $ERROR = $Text::Template::ERROR;

    $self->_rebuild_safe if $self->safe && $self->safe_disposable;

    if ( defined $computed && $self->caching ) {
        if ( ref $template && $self->cache_stringrefs ) {
            $self->_cache->set( $$template, $tt, 'never' );
        }
        else {                    # filenames
            $self->_cache->set( $template, $tt,
                $self->expires > 0
                ? { expires_in => $self->expires }
                : 'never' );
        }
    }

    return $computed;
}

1;
