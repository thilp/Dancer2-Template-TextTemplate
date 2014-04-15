# NAME

Dancer2::Template::TextTemplate - Text::Template engine for Dancer2

# VERSION

version 1.002

# SYNOPSIS

To use this engine, you may configure [Dancer2](https://metacpan.org/pod/Dancer2) via `config.yml`:

    template: text_template

# DESCRIPTION

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
            safe: 1
            safe_opcodes: [ ":default", ":load" ]
            safe_disposable: 0

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

and thus you'd get:

    Program fragment delivered error
    ``Use of uninitialized value $a in addition (+) [...]

in your template output if you forgot to pass a value for `$a`.

If you don't want anything prepended to your templates, simply give a
non-dying, side-effects-free Perl expression to `prepend`, like `0` or
`""`.

## Running in a [Safe](https://metacpan.org/pod/Safe) - `safe`, `safe_opcodes`, `safe_disposable`

This option (enabled by default) makes your templates to be evaluated in a
[Safe](https://metacpan.org/pod/Safe) compartment, i.e. where some potentially dangerous operations (such as
`system`) are disabled. Note that the same Safe compartment will be used to
evaluate all your templates, unless you explicitly specify `safe_disposable:
1` (one compartment per template _evaluation_).

This Safe uses the `:default` and `:load` opcode sets (see [the Opcode
documentation](https://metacpan.org/pod/Opcode#Predefined-Opcode-Tags)), unless
you specify it otherwise with the `safe_opcodes` option. You can, of course,
mix opcodes and optags, as in:

    safe_opcodes:
        - ":default"
        - "time"

which enables the default opcode set _and_ `time`. But __be careful__: with
the previous example for instance, you don't allow `require`, and thus break
the default value of the `prepend` option (which contains `use`)!

# METHODS

## render( $template, \\%tokens )

Renders the template.

- `$template` is either a (string) filename for the template file or a reference to a string that contains the template.
- `\%tokens` is a hashref for the tokens you wish to pass to [Text::Template](https://metacpan.org/pod/Text::Template) for rendering, as if you were using `Text::Template::fill_in`.

[Carp](https://metacpan.org/pod/Croak)s if an error occurs.

# AUTHOR

Thibaut Le Page <thilp@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Thibaut Le Page.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
