use v6.d;

unit module Compress::LZString;

=begin pod

=head1 NAME

Compress::LZString - Compress and decompress data using the lzstring algorithm

=head1 SYNOPSIS

=begin code :lang<raku>

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

=end code

=head1 DESCRIPTION

This is a Raku port of lz-string, a compression algorithm in the family
of the venerable Lempel-Ziv-Welch encoding algorithm from days of old
(GIFs, CompuServe, anyone?) that has found new and exciting applications in
the world of URIs, localStorage and other space-constrained settings.

The original javascript implementation is L<here|http://pieroxy.net/blog/pages/lz-string/index.html>.
This port followed the porting guidelines with plenty of LLM help and
lots of tests.

=head1 NUANCES

The concept of a "string" is slippery in this algorithm and there are some
gotchas that are specific to Raku, which has strong Unicode foundations and
doesn't call things strings that are not strings.  To quote the reference
implementation linked above: "Well, this lib produces stuff that isn't really
a string".

The generic C<lz-compress> function follows the primary algorithm and
uses "16 bits per character" to basically create a sequence of 16-bit unsigned
integers.   You can probably think of this as just binary data
broken up into little chunks, it has nothing to do with strings or unicode
or anything text-related.

Similarly C<lz-compress-bytes> just breaks those 16-bit chunks in half,
most significant byte first.  The return type is C<Buf[uint8]>, which is
probably a little pedantic since that is what a plain C<Buf> is anyway.

Getting closer to the real world we have C<lz-compress-utf16>.  Despite
seeing the number 16, this actually only uses 15 bits.  Why?  Because
that means we have to stay underneath 32,768, so well underneath U+D800
(55,296) and as we all know, the code points from U+D800 to U+DFFF are scary
things called surrogates, which are totally invalid on their own -- a lone one
is like talking about a single pant or a scissor -- no such thing! -- some
things in life only exist as pairs.  Raku has a type for a sequence of code
points that has not been normalized -- that type is C<Uni>, so
C<lz-compress-utf16> returns a C<Uni>.

Great, you say, so can I turn that C<Uni> into a string and finally
we have a string like this algorithm claims?  Well you can but don't.
C<lz-compress-utf16($s).Str> will always give you a string but then
normalization is going to ruin your compression.  That's because
Raku uses normal-form-grapheme (NFG) which is very nice when you like this:

        > "\x0065\x0301"
        é
        > "\x00E9"
        é
        > "\x0065\x0301" eq "\x00E9"
        True

but not so nice when you want every code point preserved as it was: those two
code points went into the string and only one came back out.  So that brings us
to C<lz-compress-base64> and C<lz-compress-uri>, which use a small fixed set of
ASCII characters and make _actual_ strings (at the cost of compression
efficiency).


=head1 EXAMPLES

=head2 encode in Raku, decode in javascript

Also in C<eg/html.raku>, compress in Raku, decompress in JS:

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

=head1 SUBROUTINES

=head2 sub lz-compress(Str $input --> Buf[uint16])

Compress to a C<Buf[uint16]> of raw 16-bit values (the equivalent of lz-string's
C<compress>). Round-trips with C<lz-decompress>; not text, and not safe for URLs
or cookies.

=head2 sub lz-decompress($compressed --> Str)

Inverse of C<lz-compress>. Accepts the C<Buf[uint16]> from C<lz-compress> (or
any positional list of 16-bit values).

=head2 sub lz-compress-bytes(Str $input --> Buf[uint8])

Compress to a C<Buf[uint8]> -- the same 16-bit stream as C<lz-compress>, with each
value split into two big-endian bytes. Equivalent to lz-string's
C<compressToUint8Array>, and the best choice for interchange with other languages.

=head2 sub lz-decompress-bytes($compressed --> Str)

Inverse of C<lz-compress-bytes>. Equivalent to lz-string's
C<decompressFromUint8Array>. Accepts a C<Buf> or any positional list of bytes.

=head2 sub lz-compress-base64(Str $input --> Str)

Compress to a base64 string, padded with C<'='> to a length that is a multiple
of 4. Equivalent to lz-string's C<compressToBase64>.

=head2 sub lz-decompress-base64(Str $input --> Str)

Inverse of C<lz-compress-base64>.

=head2 sub lz-compress-utf16(Str $input --> Uni)

Compress with the packing lz-string uses for C<localStorage>: 15 bits per code
point, offset by 32, terminated with a space. Equivalent to lz-string's
C<compressToUTF16>.

Returns a C<Uni> -- a sequence of code points that has not been normalized. See
NUANCES above for why you do not want to call C<.Str> on it.

=head2 sub lz-decompress-utf16($compressed --> Str)

Inverse of C<lz-compress-utf16>. Accepts the C<Uni> from C<lz-compress-utf16>,
or a C<Str> for streams that happen to survive normalization.

=head2 sub lz-compress-uri(Str $input --> Str)

Compress to a string that needs no escaping in a URI. Same alphabet as
C<lz-compress-base64>, but with C<'-'> in place of C<'/'>, and C<'$'> in place
of C<'='> -- and no padding. Equivalent to lz-string's
C<compressToEncodedURIComponent>.

Note that C<'+'> is in that alphabet, and javascript's C<encodeURIComponent>
does escape C<'+'>. The output is safe to drop into a URI as-is (see the
example above), just don't encode it a second time.

=head2 sub lz-decompress-uri(Str $input --> Str)

Inverse of C<lz-compress-uri>. Turns spaces back into C<'+'> first, since a
C<'+'> that has been through a query string comes back out as a space.

=head1 AUTHOR

Brian Duggan

=head1 COPYRIGHT AND LICENSE

Copyright 2026 Brian Duggan

This library is free software; you can redistribute it and/or modify it under
the MIT License. The original lz-string is MIT/WTFPL by Pieroxy.

=end pod

my constant $KEY-BASE64   = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
my constant $KEY-URI-SAFE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+-\$";

my constant %VAL-BASE64   = $KEY-BASE64.comb.kv.reverse.Hash;
my constant %VAL-URI-SAFE = $KEY-URI-SAFE.comb.kv.reverse.Hash;

my sub high-surrogate($u) { 0xD800 <= $u <= 0xDBFF }
my sub low-surrogate($u)  { 0xDC00 <= $u <= 0xDFFF }

my sub codepoint-to-units($cp) {
  return $cp if $cp <= 0xFFFF;
  my $v := $cp - 0x10000;
  0xD800 + ($v +> 10), 0xDC00 + ($v +& 0x3FF);
}

my sub surrogates-to-codepoint($hi, $lo) {
  0x10000 + (($hi - 0xD800) +< 10) + ($lo - 0xDC00);
}

sub str-to-units(Str $s --> array[uint16]) {
  my uint16 @units = $s.ords.map(&codepoint-to-units).flat;
  @units;
}

sub units-to-str(@units --> Str) {
  my @out;
  my $merged = False;  # $u is the low half already consumed by the last window
  for @units.rotor(2 => -1, :partial) -> ($u, $v = 0) {
    when $merged { $merged = False }
    when high-surrogate($u) && low-surrogate($v) {
      @out.push: surrogates-to-codepoint($u, $v);
      $merged = True;
    }
    @out.push: $u;
  }
  @out.map(*.chr).join;
}

# Hash keys are comma-joined UTF-16 units.
my sub compress(Str $uncompressed, Int $bits-per-char --> List) {
  return () without $uncompressed;

  my @units = str-to-units($uncompressed);

  my %codes;
  my %to-create;
  # The phrase is tracked by key and first unit only; keeping the whole unit
  # list would make repetitive input quadratic.
  my $w-first;
  my $key-w = "";
  my $enlarge-in    = 2;
  my $next-code     = 3;
  my $num-bits      = 2;
  my @data;
  my $data-val      = 0;
  my $data-position = 0;

  my sub add-bit($bit) {
    $data-val = ($data-val +< 1) +| $bit;
    return if ++$data-position < $bits-per-char;
    @data.push: $data-val;
    $data-val      = 0;
    $data-position = 0;
  }

  my sub write-bits(Int $value is copy, Int $n) {
    for ^$n {
      add-bit($value +& 1);
      $value +>= 1;
    }
  }

  my sub write-zero-bits(Int $n) {
    add-bit(0) for ^$n;
  }

  my sub enlarge {
    return if --$enlarge-in;
    $enlarge-in = 2 ** $num-bits;
    $num-bits++;
  }

  my sub output-w {
    LEAVE enlarge;
    unless %to-create{$key-w}:delete {
      write-bits(%codes{$key-w}, $num-bits);
      return;
    }
    my $code = $w-first;
    if $code < 256 {
      write-zero-bits($num-bits);              # tag 0: 8-bit literal
      write-bits($code, 8);
    } else {
      write-bits(1, $num-bits);                # tag 1: 16-bit literal
      write-bits($code, 16);
    }
    enlarge;
  }

  for @units -> $unit {
    my $key-c = ~$unit;
    unless %codes{$key-c}:exists {
      %codes{$key-c} = $next-code++;
      %to-create{$key-c}  = True;
    }
    my $key-wc = $key-w eq "" ?? $key-c !! "$key-w,$key-c";
    if %codes{$key-wc}:exists {
      $w-first //= $unit;
      $key-w = $key-wc;
    } else {
      output-w;
      %codes{$key-wc} = $next-code++;
      $w-first = $unit;
      $key-w   = $key-c;
    }
  }

  output-w with $w-first;

  write-bits(2, $num-bits);                      # end of stream

  repeat { add-bit(0) } until $data-position == 0;

  @data.List;
}

# $reset-value is the high-bit mask for the packing width.
my sub decompress(Int $length, Int $reset-value, &get-next-value --> Str) {
  my @codes = 0, 1, 2;
  my $enlarge-in = 4;
  my $next-code  = 4;
  my $num-bits   = 3;
  my @result;

  my $data-val      = get-next-value(0);
  my $data-position = $reset-value;
  my $data-index    = 1;

  my sub read-bits(Int $n --> Int) {
    my $bits     = 0;
    my $maxpower = 2 ** $n;
    my $power    = 1;
    while $power != $maxpower {
      NEXT $power *= 2;
      $bits +|= $power if $data-val +& $data-position;
      $data-position +>= 1;
      next if $data-position;
      $data-position = $reset-value;
      $data-val      = get-next-value($data-index++);
    }
    $bits;
  }

  my sub enlarge {
    return if --$enlarge-in;
    $enlarge-in = 2 ** $num-bits;
    $num-bits++;
  }

  my @c;
  given read-bits(2) {
    when 0  { @c = read-bits(8), }
    when 1  { @c = read-bits(16), }
    when 2  { return "" }
  }
  @codes[3] = @c;
  my @w = @c;
  @result.append: @c;

  loop {
    return "" if $data-index > $length;

    my $code = read-bits($num-bits);
    given $code {
      when 0 {
        @codes[$next-code++] = [read-bits(8),];
        $code = $next-code - 1;
        enlarge;
      }
      when 1 {
        @codes[$next-code++] = [read-bits(16),];
        $code = $next-code - 1;
        enlarge;
      }
      when 2 {
        return units-to-str(@result);
      }
    }

    my @entry;
    if @codes[$code]:exists && @codes[$code].defined {
      @entry = @codes[$code].list;
    } elsif $code == $next-code {
      @entry = |@w, @w[0];
    } else {
      return Str;
    }
    @result.append: @entry;

    @codes[$next-code++] = [|@w, @entry[0]];
    @w = @entry;
    enlarge;
  }
}

sub lz-compress(Str $input --> Buf[uint16]) is export {
  return Buf[uint16].new without $input;
  Buf[uint16].new(compress($input, 16));
}

sub lz-decompress($compressed --> Str) is export {
  return "" without $compressed;
  my @units = $compressed.list;
  return Str unless @units;
  # Truncated input reads past the end; JS gets NaN there, which masks to zero.
  decompress(@units.elems, 32768, -> $i { @units[$i] // 0 });
}

sub lz-compress-bytes(Str $input --> Buf[uint8]) is export {
  return Buf[uint8].new without $input;
  my $buf = Buf[uint8].new;
  for compress($input, 16) -> $unit {
    $buf.push: $unit +> 8, $unit +& 0xFF;
  }
  $buf;
}

sub lz-decompress-bytes($compressed --> Str) is export {
  return "" without $compressed;
  my @bytes = $compressed.list;
  return Str unless @bytes;
  my @units = (^(@bytes.elems div 2)).map: { @bytes[$_ * 2] * 256 + @bytes[$_ * 2 + 1] };
  return Str unless @units;
  decompress(@units.elems, 32768, -> $i { @units[$i] // 0 });
}

sub lz-compress-base64(Str $input --> Str) is export {
  return "" without $input;
  my $res = compress($input, 6).map({ $KEY-BASE64.substr($_, 1) }).join;
  given $res.chars % 4 {
    when 1  { $res ~ "===" }
    when 2  { $res ~ "==" }
    when 3  { $res ~ "=" }
    default { $res }
  }
}

sub lz-decompress-base64(Str $input --> Str) is export {
  return "" without $input;
  return Str if $input eq "";
  my @chars = $input.comb;
  decompress(@chars.elems, 32, -> $i { %VAL-BASE64{ @chars[$i] } // 0 });
}

sub lz-compress-utf16(Str $input --> Uni) is export {
  return Uni.new without $input;
  Uni.new(|compress($input, 15).map(* + 32), 32);   # trailing space
}

sub lz-decompress-utf16($compressed --> Str) is export {
  return "" without $compressed;
  # A Str needs .ords; its .list is the whole string as one element.
  my @ords = $compressed ~~ Str ?? $compressed.ords !! $compressed.list;
  return Str unless @ords;
  decompress(@ords.elems, 16384, -> $i { (@ords[$i] // 32) - 32 });
}

sub lz-compress-uri(Str $input --> Str) is export {
  return "" without $input;
  compress($input, 6).map({ $KEY-URI-SAFE.substr($_, 1) }).join;
}

sub lz-decompress-uri(Str $input is copy --> Str) is export {
  return "" without $input;
  return Str if $input eq "";
  $input .= subst(' ', '+', :g);
  my @chars = $input.comb;
  decompress(@chars.elems, 32, -> $i { %VAL-URI-SAFE{ @chars[$i] } // 0 });
}
