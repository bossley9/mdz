const th = @import("./test_helpers.zig");

test "4.1 43-2" {
    try th.expectParseRMD(
        \\---
    ,
        \\<hr />
    );
}

test "4.1 44" {
    try th.expectParseRMD(
        \\+++
    ,
        \\<p>+++</p>
    );
}

test "4.1 45" {
    try th.expectParseRMD(
        \\===
    ,
        \\<p>===</p>
    );
}

test "4.1 46" {
    try th.expectParseRMD(
        \\--
        \\**
        \\__
    ,
        \\<p>--
        \\**
        \\__</p>
    );
}

test "4.1 50-2" {
    try th.expectParseRMD(
        \\-------------------------------------
    ,
        \\<hr />
    );
}

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

test "4.2 62" {
    try th.expectParseRMD(
        \\# foo
        \\## foo
        \\### foo
        \\#### foo
        \\##### foo
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

test "4.2 63" {
    try th.expectParseRMD(
        \\####### foo
    ,
        \\<p>####### foo</p>
    );
}

test "4.2 64" {
    try th.expectParseRMD(
        \\#5 bolt
        \\
        \\#hashtag
    ,
        \\<p>#5 bolt</p>
        \\<p>#hashtag</p>
    );
}

// TODO implement inlines
// test "4.2 65" {
//     try th.expectParseRMD(
//         \\\## foo
//     ,
//         \\<p>## foo</p>
//     );
// }

// TODO implement inlines
// test "4.2 66" {
//     try th.expectParseRMD(
//         \\\# foo *bar* \*baz\*
//     ,
//         \\<h1>foo <em>bar</em> *baz*</h1>
//     );
// }

test "4.2 68-2" {
    try th.expectParseRMD(
        \\ ### foo
    ,
        \\<p> ### foo</p>
    );
}

test "4.2 70-2" {
    try th.expectParseRMD(
        \\foo
        \\    # bar
    ,
        \\<p>foo
        \\    # bar</p>
    );
}

test "4.2 74" {
    try th.expectParseRMD(
        \\### foo ### b
    ,
        \\<h3>foo ### b</h3>
    );
}

test "4.2 75" {
    try th.expectParseRMD(
        \\# foo#
    ,
        \\<h1>foo#</h1>
    );
}

// TODO implement inlines
// test "4.2 76" {
//     try th.expectParseRMD(
//         \\### foo \###
//         \\## foo #\##
//         \\# foo \#
//     ,
//         \\<h3>foo ###</h3>
//         \\<h2>foo ###</h2>
//         \\<h1>foo #</h1>
//     );
// }

test "4.2 77-2" {
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

test "4.2 78-2" {
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

test "4.2 79" {
    try th.expectParseRMD(
        \\## 
        \\# 
        \\### 
    ,
        \\<h2></h2>
        \\<h1></h1>
        \\<h3></h3>
    );
}

test "4.2 79-2" {
    try th.expectParseRMD(
        \\# Hello
        \\world!
    ,
        \\<h1>Hello</h1>
        \\<p>world!</p>
    );
}

test "4.8 219" {
    try th.expectParseRMD(
        \\aaa
        \\
        \\bbb
    ,
        \\<p>aaa</p>
        \\<p>bbb</p>
    );
}

test "4.8 220" {
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

test "4.8 221" {
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

test "4.8 222-2" {
    try th.expectParseRMD(
        \\  aaa
        \\ bbb
    ,
        \\<p>  aaa
        \\ bbb</p>
    );
}

test "4.9 227-2" {
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
