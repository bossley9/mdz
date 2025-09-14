const th = @import("./test_helpers.zig");

// TODO implement lists
// test "4.1 57-2" {
//     try th.expectParseRMD(
//         \\- foo
//         \\---
//         \\- bar
//     ,
//         \\TODO
//     );
// }

test "4.9 227-3" {
    try th.expectParseRMD(
        \\  
        \\
        \\aaa
        \\  
        \\
        \\# aaa
        \\
        \\  
    ,
        \\<p>  </p>
        \\<p>aaa
        \\  </p>
        \\<h1>aaa</h1>
        \\<p>  </p>
    );
}

test "5.1 228" {
    try th.expectParseRMD(
        \\> # Foo
        \\> bar
        \\> baz
    ,
        \\<blockquote>
        \\<h1>Foo</h1>
        \\<p>bar
        \\baz</p>
        \\</blockquote>
    );
}

test "5.1 232" {
    try th.expectParseRMD(
        \\> # Foo
        \\> bar
        \\baz
    ,
        \\<blockquote>
        \\<h1>Foo</h1>
        \\<p>bar
        \\baz</p>
        \\</blockquote>
    );
}

test "5.1 233" {
    try th.expectParseRMD(
        \\> bar
        \\baz
        \\> foo
    ,
        \\<blockquote>
        \\<p>bar
        \\baz
        \\foo</p>
        \\</blockquote>
    );
}

test "5.1 234-2" {
    try th.expectParseRMD(
        \\> foo
        \\---
    ,
        \\<blockquote>
        \\<p>foo
        \\---</p>
        \\</blockquote>
    );
}

// TODO implement code block
// test "5.1 237-2" {
//     try th.expectParseRMD(
//         \\> ```
//         \\foo
//         \\```
//     ,
//         \\<blockquote>
//         \\<pre><code>foo
//         \\</code></pre></blockquote>
//     );
// }

test "5.1 239" {
    try th.expectParseRMD(
        \\>
    ,
        \\<blockquote>
        \\</blockquote>
    );
}

test "5.1 240-2" {
    try th.expectParseRMD(
        \\>
        \\>  
        \\> 
    ,
        \\<blockquote>
        \\<p> </p>
        \\</blockquote>
    );
}

test "5.1 241-2" {
    try th.expectParseRMD(
        \\>
        \\> foo
        \\> 
    ,
        \\<blockquote>
        \\<p>foo</p>
        \\</blockquote>
    );
}

test "5.1 242" {
    try th.expectParseRMD(
        \\> foo
        \\
        \\> bar
    ,
        \\<blockquote>
        \\<p>foo</p>
        \\</blockquote>
        \\<blockquote>
        \\<p>bar</p>
        \\</blockquote>
    );
}

test "5.1 243" {
    try th.expectParseRMD(
        \\> foo
        \\> bar
    ,
        \\<blockquote>
        \\<p>foo
        \\bar</p>
        \\</blockquote>
    );
}

test "5.1 244-2" {
    try th.expectParseRMD(
        \\> foo
        \\> 
        \\> bar
    ,
        \\<blockquote>
        \\<p>foo</p>
        \\<p>bar</p>
        \\</blockquote>
    );
}

test "5.1 247" {
    try th.expectParseRMD(
        \\> bar
        \\baz
    ,
        \\<blockquote>
        \\<p>bar
        \\baz</p>
        \\</blockquote>
    );
}

test "5.1 248" {
    try th.expectParseRMD(
        \\> bar
        \\
        \\baz
    ,
        \\<blockquote>
        \\<p>bar</p>
        \\</blockquote>
        \\<p>baz</p>
    );
}

test "5.1 250" {
    try th.expectParseRMD(
        \\> > > foo
        \\bar
    ,
        \\<blockquote>
        \\<blockquote>
        \\<blockquote>
        \\<p>foo
        \\bar</p>
        \\</blockquote>
        \\</blockquote>
        \\</blockquote>
    );
}

test "5.1 251-2" {
    try th.expectParseRMD(
        \\> > > foo
        \\> bar
        \\> > baz
    ,
        \\<blockquote>
        \\<blockquote>
        \\<blockquote>
        \\<p>foo
        \\bar
        \\baz</p>
        \\</blockquote>
        \\</blockquote>
        \\</blockquote>
    );
}

// -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

// TODO inlines
// test "2.3.1" {
//     try th.expectParseRMD(
//         \\\*not bold\*
//     ,
//         \\<p>*not bold*</p>
//     );
// }

// TODO inlines
// test "2.3.2" {
//     try th.expectParseRMD(
//         \\\> not blockquote
//     ,
//         \\<p>&gt; not a blockquote</p>
//     );
// }

// TODO inlines
// test "2.3.3" {
//     try th.expectParseRMD(
//         \\My name is \\ John.
//     ,
//         \\<p>My name is \ John.</p>
//     );
// }

// TODO inlines
// test "2.3.4" {
//     try th.expectParseRMD(
//         \\```zig
//         \\const str =
//         \\  \\hello,
//         \\  \\world!
//         \\;
//         \\```
//     ,
//         \\<pre><code class="language-zig">const str =
//         \\  \\hello,
//         \\  \\world!
//         \\;
//         \\</code></pre>
//     );
// }

test "4.1.1" {
    try th.expectParseRMD(
        \\
        \\
        \\aaa
        \\
        \\
        \\# aaa
        \\
        \\
    ,
        \\<p>aaa</p>
        \\<h1>aaa</h1>
    );
}

test "4.2.1" {
    try th.expectParseRMD(
        \\aaa
        \\
        \\bbb
    ,
        \\<p>aaa</p>
        \\<p>bbb</p>
    );
}

test "4.2.1-2" {
    try th.expectParseRMD(
        \\Hello, world!
    ,
        \\<p>Hello, world!</p>
    );
}

test "4.2.2" {
    try th.expectParseRMD(
        \\aaa
        \\bbb
        \\
        \\ccc
        \\ddd
    ,
        \\<p>aaa
        \\bbb</p>
        \\<p>ccc
        \\ddd</p>
    );
}

test "4.2.3" {
    try th.expectParseRMD(
        \\aaa
        \\
        \\
        \\
        \\bbb
    ,
        \\<p>aaa</p>
        \\<p>bbb</p>
    );
}

test "4.2.4" {
    try th.expectParseRMD(
        \\  aaa
        \\ bbb
    ,
        \\<p>  aaa
        \\ bbb</p>
    );
}

test "4.3.1" {
    try th.expectParseRMD(
        \\---
    ,
        \\<hr />
    );
}

test "4.3.2" {
    try th.expectParseRMD(
        \\--
    ,
        \\<p>--</p>
    );
}

test "4.3.3" {
    try th.expectParseRMD(
        \\---------------------------------
    ,
        \\<hr />
    );
}

test "4.3.4" {
    try th.expectParseRMD(
        \\foo
        \\---
        \\bar
    ,
        \\<p>foo
        \\---
        \\bar</p>
    );
}

test "4.4.1" {
    try th.expectParseRMD(
        \\# foo
        \\
        \\## foo
        \\
        \\### foo
        \\
        \\#### foo
        \\
        \\##### foo
        \\
        \\###### foo
    ,
        \\<h1>foo</h1>
        \\<h2>foo</h2>
        \\<h3>foo</h3>
        \\<h4>foo</h4>
        \\<h5>foo</h5>
        \\<h6>foo</h6>
    );
}

test "4.4.2" {
    try th.expectParseRMD(
        \\####### foo
    ,
        \\<p>####### foo</p>
    );
}

test "4.4.3" {
    try th.expectParseRMD(
        \\#5 bolt
        \\
        \\#hashtag
    ,
        \\<p>#5 bolt</p>
        \\<p>#hashtag</p>
    );
}

// TODO inlines
// test "4.4.4" {
//     try th.expectParseRMD(
//         \\\## foo
//     ,
//         \\<p>## foo</p>
//     );
// }

// TODO inlines
// test "4.4.5" {
//     try th.expectParseRMD(
//         \\# foo *bar* \*baz\*
//     ,
//         \\<h1>foo <em>bar</em> *baz*</h1>
//     );
// }

test "4.4.6" {
    try th.expectParseRMD(
        \\ ### foo
    ,
        \\<p> ### foo</p>
    );
}

test "4.4.7" {
    try th.expectParseRMD(
        \\foo
        \\    # bar
    ,
        \\<p>foo
        \\    # bar</p>
    );
}

test "4.4.8" {
    try th.expectParseRMD(
        \\---
        \\
        \\## foo
        \\
        \\---
    ,
        \\<hr />
        \\<h2>foo</h2>
        \\<hr />
    );
}

test "4.4.9" {
    try th.expectParseRMD(
        \\Foo bar
        \\# baz
        \\Bar foo
    ,
        \\<p>Foo bar
        \\# baz
        \\Bar foo</p>
    );
}

test "4.4.10" {
    try th.expectParseRMD(
        \\# Hello
        \\world!
    ,
        \\<h1>Hello</h1>
        \\<p>world!</p>
    );
}

test "4.5.1" {
    try th.expectParseRMD(
        \\```
        \\<
        \\ >
        \\```
    ,
        \\<pre><code>&lt;
        \\ &gt;
        \\</code></pre>
    );
}

test "4.5.2" {
    try th.expectParseRMD(
        \\```
        \\aaa
        \\~~~
        \\```
    ,
        \\<pre><code>aaa
        \\~~~
        \\</code></pre>
    );
}

test "4.5.3" {
    try th.expectParseRMD(
        \\```
        \\content
        \\```
    ,
        \\<pre><code>content
        \\</code></pre>
    );
}

test "4.5.4" {
    try th.expectParseRMD(
        \\```
    ,
        \\<pre><code></code></pre>
    );
}

test "4.5.5" {
    try th.expectParseRMD(
        \\```
        \\aaa
    ,
        \\<pre><code>aaa
        \\</code></pre>
    );
}

test "4.5.6" {
    try th.expectParseRMD(
        \\> ```
        \\> aaa
        \\
        \\bbb
    ,
        \\<blockquote>
        \\<pre><code>aaa
        \\</code></pre>
        \\</blockquote>
        \\<p>bbb</p>
    );
}

test "4.5.7" {
    try th.expectParseRMD(
        \\```
        \\
        \\
        \\```
    ,
        \\<pre><code>
        \\
        \\</code></pre>
    );
}

test "4.5.8" {
    try th.expectParseRMD(
        \\```
        \\```
    ,
        \\<pre><code></code></pre>
    );
}

test "4.5.9" {
    try th.expectParseRMD(
        \\ ```
        \\ aaa
        \\aaa
        \\```
    ,
        \\<p> ```
        \\ aaa
        \\aaa
        \\```</p>
    );
}

test "4.5.10" {
    try th.expectParseRMD(
        \\```ruby
        \\def foo(x)
        \\  return 3
        \\end
        \\```
    ,
        \\<pre><code class="language-ruby">def foo(x)
        \\  return 3
        \\end
        \\</code></pre>
    );
}

test "4.5.11" {
    try th.expectParseRMD(
        \\```;
        \\```
    ,
        \\<pre><code class="language-;"></code></pre>
    );
}
