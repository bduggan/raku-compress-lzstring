#!/usr/bin/env raku
use Compress::LZString;

# Compress in Raku, stash it in a URL fragment, decompress in the browser with
# the original lz-string javascript library.

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
