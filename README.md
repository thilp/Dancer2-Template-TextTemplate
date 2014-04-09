# NAME

Dancer2::Template::TextTemplate - Text::Template engine for Dancer2

# VERSION

version 0.2

# SYNOPSIS

To use this engine, you may configure [Dancer2](https://metacpan.org/pod/Dancer2) via `config.yml`:

    template: text_template

# DESCRIPTION

__This is an alpha version: it basically works, but it has not been
extensively tested and it misses interesting features.__

This template engine allows you to use [Text::Template](https://metacpan.org/pod/Text::Template) in [Dancer2](https://metacpan.org/pod/Dancer2).

## Configuration

Here are all available options, as you would set them in a `config.yml`, with
their __default__ values:

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

## Global caching - `caching`, `expires`

Contrary to other template engines (like [Template::Toolkit](https://metacpan.org/pod/Template::Toolkit)), where _one_
instance may work on _multiple_ templates, _one_ [Text::Template](https://metacpan.org/pod/Text::Template) instance
is created _for each_ template. Therefore, if:

- you don't use a huge amount of different templates;
- you don't use each template just once;

then it may be interesting to __cache__ Text::Template instances for later use.
Since these conditions seem to be common, this engine uses a cache (_via_
[CHI](https://metacpan.org/pod/CHI)) __by default__.

If you're OK with caching, you should specify a __timeout__ (`expires`) after
which cached Text::Template instances are to be refreshed, since you might
have changed your template sources without restarting Dancer2. By default,
this engine uses `expires: 3600` (one hour). Use `0` to tell it that
templates never expire.

If you don't want any caching, just set `caching` to `0`.

## "String-ref templates" caching - `cache_stringrefs`

Just like with [Dancer2::Template::Toolkit](https://metacpan.org/pod/Dancer2::Template::Toolkit), you can pass templates either as
filenames (for a template file) or string references ("string-refs", which are
dereferenced and used as the template's content). In some cases, you may want
to disable caching for string-refs only: for instance, if you generate a lot
of templates on-the-fly and use them only once, caching them is useless and
fills your cache. You can therefore disable caching _for string-refs only_ by
setting `cache_stringrefs` to `0`.

Note that if you set `caching` to `0`, you don't have _any_ caching, so
`cache_stringrefs` is ignored.

## Custom delimiters - `delimiters`

The `delimiters` option allows you to specify a custom delimiters pair
(opening and closing) for your templates. See the [Text::Template](https://metacpan.org/pod/Text::Template)
documentation for more about delimiters, since this module just pass them to
Text::Template. This option defaults to `{` and `}`, meaning that in `a
{b} c`, `b` (and only `b`) will be interpolated.

## Prepending code - `prepend`

This option specifies Perl code run by Text::Template _before_ evaluating
each template. For instance, with this option's default value of:

    use strict;
    use warnings;

then evaluating the following template:

    hello { $a = 'you' }

is the same as evaluating:

    {
        use strict;
        use warnings;
        ""
    }
    hello { $a = 'you' }

and thus you'll get a warning if `$a` is uninitialized.

## Running in a [Safe](https://metacpan.org/pod/Safe) - `safe`

Not yet implemented!

# METHODS

## render( $template, \\%tokens )

Renders the template.

- `$template` is either a (string) filename for the template file or a

    reference to a string that contains the template.

- `\%tokens` is a hashref for the tokens you wish to pass to

    [Text::Template](https://metacpan.org/pod/Text::Template) for rendering, as if you were using
    `Text::Template::fill_in`.

[Carp](https://metacpan.org/pod/Croak)s if an error occurs.

# AUTHOR

Thibaut Le Page <thilp@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Thibaut Le Page.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
