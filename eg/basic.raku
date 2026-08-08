#!/usr/bin/env raku

use Compress::LZString;

my Str $s = 'hello, world';
say lz-decompress( lz-compress $s );               # hello, world
say lz-decompress-utf16( lz-compress-utf16($s) );        # Uni -- 15-bit packing, +32
say lz-decompress-base64( lz-compress-base64 $s ); # hello, world
say lz-decompress-uri( lz-compress-uri $s );       # hello, world
say lz-decompress-bytes( lz-compress-bytes($s) );        # Buf[uint8] -- big-endian byte pairs

say lz-compress($s).WHAT;
say lz-compress-utf16($s).WHAT;
say lz-compress-base64($s).WHAT;
say lz-compress-uri($s).WHAT;
say lz-compress-bytes($s).WHAT;

say lz-compress-utf16($s).Str;

