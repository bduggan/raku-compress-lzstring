[![Actions Status](https://github.com/bduggan/raku-compress-lzstring/actions/workflows/linux.yml/badge.svg)](https://github.com/bduggan/raku-compress-lzstring/actions/workflows/linux.yml)
[![Actions Status](https://github.com/bduggan/raku-compress-lzstring/actions/workflows/macos.yml/badge.svg)](https://github.com/bduggan/raku-compress-lzstring/actions/workflows/macos.yml)

NAME
====

Compress::LZString - Compress and decompress data using the lzstring algorithm

SYNOPSIS
========

```raku
use Compress::LZString;

my Str $s = 'hello, world';
say lz-decompress( lz-compress $s );               # hello, world
say lz-decompress-bytes( lz-compress-bytes $s );   # hello, world
say lz-decompress-utf16( lz-compress-utf16 $s );   # hello, world
say lz-decompress-base64( lz-compress-base64 $s ); # hello, world
say lz-decompress-uri( lz-compress-uri $s );       # hello, world

say lz-compress($s).WHAT;         # (Buf[uint16])
say lz-compress-bytes($s).WHAT;   # (Buf[uint8])
say lz-compress-utf16($s).WHAT;   # (Uni)
say lz-compress-base64($s).WHAT;  # (Str)
say lz-compress-uri($s).WHAT;     # (Str)
```

DESCRIPTION
===========

This is a Raku port of lz-string, a compression algorithm in the family of the venerable Lempel-Ziv-Welch encoding algorithm from days of old (GIFs, CompuServe, anyone?) that has found new and exciting applications in the world of URIs, localStorage and other space-constrained settings.

The original javascript implementation is [here](http://pieroxy.net/blog/pages/lz-string/index.html). This port followed the porting guidelines with plenty of LLM help and lots of tests.

NUANCES
=======

The concept of a "string" is slippery in this algorithm and there are some gotchas that are specific to Raku, which has strong Unicode foundations and doesn't call things strings that are not strings. To quote the reference implementation linked above: "Well, this lib produces stuff that isn't really a string".

The generic `lz-compress` function follows the primary algorithm and uses "16 bits per character" to basically create a sequence of 16-bit unsigned integers. You can probably think of this as just binary data broken up into little chunks, it has nothing to do with strings or unicode or anything text-related.

Similarly `lz-compress-bytes` just breaks those 16-bit chunks in half, most significant byte first. The return type is `Buf[uint8]`, which is probably a little pedantic since that is what a plain `Buf` is anyway.

Getting closer to the real world we have `lz-compress-utf16`. Despite seeing the number 16, this actually only uses 15 bits. Why? Because that means we have to stay underneath 32,768, so well underneath U+D800 (55,296) and as we all know, the code points from U+D800 to U+DFFF are scary things called surrogates, which are totally invalid on their own -- a lone one is like talking about a single pant or a scissor -- no such thing! -- some things in life only exist as pairs. Raku has a type for a sequence of code points that has not been normalized -- that type is `Uni`, so `lz-compress-utf16` returns a `Uni`.

Great, you say, so can I turn that `Uni` into a string and finally we have a string like this algorithm claims? Well you can but don't. `lz-compress-utf16($s).Str` will always give you a string but then normalization is going to ruin your compression. That's because Raku uses normal-form-grapheme (NFG) which is very nice when you like this:

    > "\x0065\x0301"
    é
    > "\x00E9"
    é
    > "\x0065\x0301" eq "\x00E9"
    True

but not so nice when you want every code point preserved as it was: those two code points went into the string and only one came back out. So that brings us to `lz-compress-base64` and `lz-compress-uri`, which use a small fixed set of ASCII characters and make _actual_ strings (at the cost of compression efficiency).

EXAMPLES
========

encode in Raku, decode in javascript
------------------------------------

Also in `eg/html.raku`, compress in Raku, decompress in JS:

    use Compress::LZString;

    my $message = "hello world";
    my $frag    = lz-compress-uri($message);
    my $file    = "out.html".IO.absolute;
    my $url     = "file://$file#$frag";

    my $html = q:to/HTML/;
        <!doctype html>
        <html>
        <head>
          <script src="https://cdn.jsdelivr.net/npm/lz-string@1.5.0/libs/lz-string.min.js"></script>
        </head>
        <body>
          <script>
            var frag = location.hash.slice(1);
            document.write(
              LZString.decompressFromEncodedURIComponent(frag)
            )
          </script>
        </body>
        </html>
        HTML

    $file.IO.spurt: $html;

    shell "xdg-open '$url'";

SUBROUTINES
===========

sub lz-compress(Str $input --> Buf[uint16])
-------------------------------------------

Compress to a `Buf[uint16]` of raw 16-bit values (the equivalent of lz-string's `compress`). Round-trips with `lz-decompress`; not text, and not safe for URLs or cookies.

sub lz-decompress($compressed --> Str)
--------------------------------------

Inverse of `lz-compress`. Accepts the `Buf[uint16]` from `lz-compress` (or any positional list of 16-bit values).

sub lz-compress-bytes(Str $input --> Buf[uint8])
------------------------------------------------

Compress to a `Buf[uint8]` -- the same 16-bit stream as `lz-compress`, with each value split into two big-endian bytes. Equivalent to lz-string's `compressToUint8Array`, and the best choice for interchange with other languages.

sub lz-decompress-bytes($compressed --> Str)
--------------------------------------------

Inverse of `lz-compress-bytes`. Equivalent to lz-string's `decompressFromUint8Array`. Accepts a `Buf` or any positional list of bytes.

sub lz-compress-base64(Str $input --> Str)
------------------------------------------

Compress to a base64 string, padded with `'='` to a length that is a multiple of 4. Equivalent to lz-string's `compressToBase64`.

sub lz-decompress-base64(Str $input --> Str)
--------------------------------------------

Inverse of `lz-compress-base64`.

sub lz-compress-utf16(Str $input --> Uni)
-----------------------------------------

Compress with the packing lz-string uses for `localStorage`: 15 bits per code point, offset by 32, terminated with a space. Equivalent to lz-string's `compressToUTF16`.

Returns a `Uni` -- a sequence of code points that has not been normalized. See NUANCES above for why you do not want to call `.Str` on it.

sub lz-decompress-utf16($compressed --> Str)
--------------------------------------------

Inverse of `lz-compress-utf16`. Accepts the `Uni` from `lz-compress-utf16`, or a `Str` for streams that happen to survive normalization.

sub lz-compress-uri(Str $input --> Str)
---------------------------------------

Compress to a string that needs no escaping in a URI. Same alphabet as `lz-compress-base64`, but with `'-'` in place of `'/'`, and `'$'` in place of `'='` -- and no padding. Equivalent to lz-string's `compressToEncodedURIComponent`.

Note that `'+'` is in that alphabet, and javascript's `encodeURIComponent` does escape `'+'`. The output is safe to drop into a URI as-is (see the example above), just don't encode it a second time.

sub lz-decompress-uri(Str $input --> Str)
-----------------------------------------

Inverse of `lz-compress-uri`. Turns spaces back into `'+'` first, since a `'+'` that has been through a query string comes back out as a space.

AUTHOR
======

Brian Duggan

COPYRIGHT AND LICENSE
=====================

Copyright 2026 Brian Duggan

This library is free software; you can redistribute it and/or modify it under the MIT License. The original lz-string is MIT/WTFPL by Pieroxy.

