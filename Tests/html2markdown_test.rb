#!/usr/bin/env ruby -wEutf-8
# Run with: ruby Tests/html2markdown_test.rb
#
# Each expectation was derived by tracing html2text 2.35's state machine
# (the python original this script replaces) for the same input, so the
# port is pinned to the old output, quirks included: list items are always
# indented two spaces per level, a <br> inside a wrapped paragraph becomes
# a paragraph break, and a <pre> that opens the document is not indented
# on its first line.
require File.expand_path("../Support/bin/html2markdown", __dir__)

$failures = 0

def check(label, html, want)
	got = HTML2Markdown.convert(html)
	return if got == want
	puts "FAIL #{label}:\n  want #{want.inspect}\n  got  #{got.inspect}"
	$failures += 1
end

check 'heading and inline markup',
	'<h1>Title</h1><p>Hello <em>world</em> and <strong>bold</strong>.</p>',
	"# Title\n\nHello _world_ and **bold**.\n\n"

check 'heading levels',
	'<h2>Two</h2><h6>Six</h6>',
	"## Two\n\n###### Six\n\n"

check 'links are numbered references listed at the end; a title is kept',
	'<p>See <a href="http://x.y/" title="XY">this</a> and <a href="http://x.y/">again</a>.</p>',
	"See [this][1] and [again][2].\n\n   [1]: http://x.y/ (XY)\n   [2]: http://x.y/\n\n"

check 'the same href and title reuse one reference',
	'<p><a href="a">one</a> <a href="a">two</a></p>',
	"[one][1] [two][1]\n\n   [1]: a\n\n"

check 'a link without href is plain text',
	'<p><a name="x">anchor</a></p>',
	"anchor\n\n"

check 'image',
	'<p><img src="i.png" alt="pic"></p>',
	"![pic][1]\n\n   [1]: i.png\n\n"

check 'unordered list, nested',
	'<ul><li>one</li><li>two<ul><li>nested</li></ul></li></ul>',
	"  * one\n  * two\n\n    * nested\n\n"

check 'ordered list',
	'<ol><li>a</li><li>b</li></ol>',
	"  1. a\n  2. b\n\n"

check 'pre after a paragraph is indented four spaces',
	"<p>a</p><pre>x\ny</pre>",
	"a\n\n    x\n    y\n\n"

check 'code inline',
	'<p>run <code>ls</code> now</p>',
	"run `ls` now\n\n"

check 'horizontal rule',
	'<p>a</p><hr><p>b</p>',
	"a\n\n* * *\n\nb\n\n"

check 'blockquote',
	'<blockquote><p>quoted</p></blockquote>',
	"> quoted\n\n"

check 'whitespace collapses, nbsp becomes a space, entities are decoded',
	"<p>a&nbsp;b &amp; c\n   d &lt;e&gt;</p>",
	"a b & c d <e>\n\n"

check 'head, style and script are dropped',
	'<html><head><title>T</title><style>p{}</style></head><body><p>hi</p><script>x()</script></body></html>',
	"hi\n\n"

check 'non-ASCII text passes through',
	'<p>Café — “déjà vu” ©</p>',
	"Café — “déjà vu” ©\n\n"

check 'long paragraphs wrap at 78 columns',
	'<p>' + (['word'] * 30).join(' ') + '</p>',
	(['word'] * 15).join(' ') + "\n" + (['word'] * 15).join(' ') + "\n\n"

check 'reference lines are not wrapped',
	'<p><a href="http://example.com/' + 'x' * 90 + '">l</a></p>',
	"[l][1]\n\n   [1]: http://example.com/" + 'x' * 90 + "\n\n"

check 'abbreviation definitions are listed at the end',
	'<p>The <abbr title="World Wide Web">WWW</abbr> is big.</p>',
	"The WWW is big.\n\n  *[WWW]: World Wide Web\n\n"

check 'definition list',
	'<dl><dt>term</dt><dd>meaning</dd></dl>',
	"term\n\n    meaning\n\n"  # the wrapper puts a blank line after the wrapped term

if $failures.zero?
	puts 'OK'
else
	puts "#{$failures} failure(s)"
	exit 1
end
