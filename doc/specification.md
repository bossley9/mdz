# Refined Markdown Spec

<small>
  This specification is based loosely on the <a href="https://spec.commonmark.org/0.31.2/">CommonMark 0.31.2 specification</a> and draws inspiration from the <a href="https://github.github.com/gfm/">Github-Flavored Markdown 0.29 specification</a> and from the <a href="https://github.com/markdown-it/markdown-it">markdown-it</a> library and its various extensions. This is licensed under a <a rel="license" href="https://creativecommons.org/licenses/by-sa/4.0/">Creative Commons Attribution-ShareAlike 4.0 International License</a>.
</small>

## 1. Prelude

### 1.1. What is Markdown?

Markdown is a plain text format for writing structured documents. The goal of Markdown is to provide a human-readable syntax that can be easily transformed into HTML. It was originally created in 2004 by [John Gruber](https://daringfireball.net/projects/markdown/syntax) and has since become relatively standardized by specifications like [CommonMark](https://commonmark.org/) and [Github-Flavored Markdown](https://github.github.com/gfm/). Since its conception, there have been many additions and extensions created for the purpose of furthering Markdown capabilities.

### 1.2 Why is a Spec Needed?

While CommonMark exists to standardize the original Markdown syntax, the spec is complicated, outdated, and ambiguous. To illustrate this, consider the following examples.

* Each of the lines below are identical according to CommonMark:
    ```plaintext
    text\r\n
    text\r
    text\n
    ```
* Each of the lines below are identical according to CommonMark:
    ```plaintext
    > blockquote
    >blockquote
       > blockquote
    >    blockquote
    ```
* Each of the lines below are identical according to CommonMark:
    ```plaintext
    ---
    ***
    * * *
    -\t-\t-
     **  * ** * ** * **
    -     -      -      -
    ```
* There are two ways to write code blocks: fenced code blocks and indented code blocks.
* There are two ways to write headings: Setext headings and ATX headings.
* Indented code blocks cannot interrupt paragraphs, but paragraphs can interrupt indented code blocks.
* There are "tight" and "loose" lists depending on the spacing between each line item.
* Paragraphs (and other blocks) can be indented up to 3 spaces and the leading whitespace will be trimmed, but 4 spaces makes the paragraph a code block.

This specification exists to clarify these edge cases and remove ambiguity.

### 1.3. What is Refined Markdown?

Refined Markdown (RMD) attempts to improve upon the CommonMark specification. This specification heavily reduces the scope and complexity of Markdown to a smart subset of the original CommonMark spec while adding popular extensions that improves Markdown document writing capabilities for the purpose of HTML conversion.

The core goals of Refined Markdown are the following:

* Reduced complexity. There should only be one syntax to write a Refined Markdown block.
* Modernization. There is no need to support an older syntax style because it holds historical significance.
* Efficiency. Implementations should be able to parse Refined Markdown without backtracking in O(n).
* WYSIWYG. The CommonMark spec handles whitespace delicately, omitting it in certain scenarios and creating code blocks or nested containers in others. Whitespace should be passed through as is.
* Close compatibility. Excluding extensions, the markup defined in this document should produce similar output to other CommonMark implementations to preserve relative backwards compatibility with existing Markdown.

## 2. Preliminaries

### 2.1. Characters and Lines

Any characters are valid in a Refined Markdown document.

A <dfn>line</dfn> is a sequence of 0 or more characters followed by a line ending.

A <dfn>line ending</dfn> is a line feed (`U+000A`) or a carriage return (`U+000D`) followed by a line ending.

A <dfn>space</dfn> is `U+0020`.

### 2.2. HTML

Refined Markdown is designed to integrate with HTML. Raw HTML can be written alongside Refined Markdown. When parsing HTML blocks, they will be passed through and outputted as is. No transformation is necessary for raw HTML blocks.

This also means that *Refined Markdown performs no sanitization*. If security is a concern, the output HTML will need to be sanitized separately.

### 2.3. Backslash Escapes

A backslash character which precedes another character means that the character will be interpreted as text and not as a block or inline marker. The backslash character is removed from the final output.

<figure>
  <figcaption>Example 2.3.1</figcaption>
<pre><code>\*not bold\*
<hr />&lt;p&gt;*not bold*&lt;/p&gt;</code></pre>
</figure>

This means that when `>`, `<` are backslash escaped, they must be translated to ampersand codes to prevent invalid HTML.

<figure>
  <figcaption>Example 2.3.2</figcaption>
<pre><code>\&gt; not a blockquote
<hr />&lt;p&gt;&amp;gt; not a blockquote&lt;/p&gt;</code></pre>
</figure>

Backslash characters will not appear in the HTML output unless they are escaped.

<figure>
  <figcaption>Example 2.3.3</figcaption>
<pre><code>My name is \\ John.
<hr />&lt;p&gt;My name is \ John.&lt;/p&gt;</code></pre>
</figure>

<figure>
  <figcaption>Example 2.3.4</figcaption>
<pre><code>\Hello, world!\
<hr />&lt;p&gt;Hello, world!&lt;/p&gt;</code></pre>
</figure>

However, backslash rules are ignored within code blocks.

<figure>
  <figcaption>Example 2.3.5</figcaption>
<pre><code>&grave;&grave;&grave;zig
const str =
  \\hello,
  \\world!
;
&grave;&grave;&grave;
<hr />&lt;pre&gt;&lt;code class="language-zig"&gt;const str =
  \\hello,
  \\world!
;
&lt;/code&gt;&lt;/pre&gt;</code></pre>
</figure>

## 3. Blocks and Inlines

The content of a Refined Markdown document is divided into blocks and inlines. <dfn>Blocks</dfn> are structural elements which may contain nested blocks within them, while <dfn>inlines</dfn> are text elements which affect styling. All blocks require a blank line separating each block with the exception of list items. Leaf blocks cannot contain other blocks while container blocks may contain child blocks. In the event of a conflict, blocks structure always takes precedence over inline structure.

## 4. Leaf Blocks

### 4.1. Blank Lines

A blank line is a line containing no text. Blank lines are ignored in output but indicate that the previous block(s) should be closed.

<figure>
  <figcaption>Example 4.1.1</figcaption>
<pre><code><br /><br />aaa<br /><br /><br /># aaa<br /><br />
<hr />&lt;p&gt;aaa&lt;/p&gt;
&lt;h1&gt;aaa&lt;/h1&gt;</code></pre>
</figure>

### 4.2. Paragraphs

A paragraph is a block that cannot be interpreted as any other kind of block. A paragraph can contain inlines.

<figure>
  <figcaption>Example 4.2.1</figcaption>
<pre><code>aaa<br /><br />bbb
<hr />&lt;p&gt;aaa&lt;/p&gt;
&lt;p&gt;bbb&lt;/p&gt;</code></pre>
</figure>

Paragraphs can continue to the next line.

<figure>
  <figcaption>Example 4.2.2</figcaption>
<pre><code>aaa
bbb<br />
ccc
ddd
<hr />&lt;p&gt;aaa
bbb&lt;/p&gt;
&lt;p&gt;ccc
ddd&lt;/p&gt;</code></pre>
</figure>

Multiple blank lines have no effect.

<figure>
  <figcaption>Example 4.2.3</figcaption>
<pre><code>aaa<br /><br /><br />
bbb
<hr />&lt;p&gt;aaa&lt;/p&gt;
&lt;p&gt;bbb&lt;/p&gt;</code></pre>
</figure>

Whitespace (and newlines) are preserved.

<figure>
  <figcaption>Example 4.2.4</figcaption>
<pre><code>  aaa
 bbb
<hr />&lt;p&gt;  aaa
 bbb&lt;/p&gt;</code></pre>
</figure>

<figure>
  <figcaption>Example 4.2.5</figcaption>
<pre><code>  <br/>
aaa
  <br /><br /># aaa<br />
  <br /><hr />&lt;p&gt;  &lt;/p&gt;
&lt;p&gt;aaa
  &lt;/p&gt;
&lt;h1&gt;aaa&lt;/h1&gt;
&lt;p&gt;  &lt;/p&gt;</code></pre>
</figure>

### 4.3. Thematic Breaks

Thematic break consists of three or more matching `-` characters at the beginning of a line.

<figure>
  <figcaption>Example 4.3.1</figcaption>
<pre><code>---
<hr />&lt;hr /&gt;</code></pre>
</figure>

<figure>
  <figcaption>Example 4.3.2</figcaption>
<pre><code>--
<hr />&lt;p&gt;--&lt;/p&gt;</code></pre>
</figure>

More than three characters may be used.

<figure>
  <figcaption>Example 4.3.3</figcaption>
<pre><code>---------------------------------
<hr />&lt;hr /&gt;</code></pre>
</figure>

Like other blocks, thematic breaks require blank lines as separation from other blocks.

<figure>
  <figcaption>Example 4.3.4</figcaption>
<pre><code>foo
---
bar
<hr />&lt;p&gt;foo
---
bar&lt;/p&gt;</code></pre>
</figure>

### 4.4. Headings

Headings begin at the start of a line and consist of 1 to 6 `#` characters followed by exactly one space followed by inlines. The heading level is equal to the number of `#` characters. Headings can only span one line.

<figure>
  <figcaption>Example 4.4.1</figcaption>
<pre><code># foo
<br />## foo
<br />### foo
<br />#### foo
<br />##### foo
<br />###### foo
<hr />&lt;h1&gt;foo&lt;/h1&gt;
&lt;h2&gt;foo&lt;/h2&gt;
&lt;h3&gt;foo&lt;/h3&gt;
&lt;h4&gt;foo&lt;/h4&gt;
&lt;h5&gt;foo&lt;/h5&gt;
&lt;h6&gt;foo&lt;/h6&gt;</code></pre>
</figure>

More than six # characters is not a heading:

<figure>
  <figcaption>Example 4.4.2</figcaption>
<pre><code>####### foo
<hr />&lt;p&gt;####### foo&lt;/p&gt;</code></pre>
</figure>

Exactly one space is required between the `#` characters and the heading's contents.

<figure>
  <figcaption>Example 4.4.3</figcaption>
<pre><code>#5 bolt<br />
#hashtag
<hr />&lt;p&gt;#5 bolt&lt;/p&gt;
&lt;p&gt;#hashtag&lt;/p&gt;</code></pre>
</figure>

This is not a heading because the first `#` is escaped:

<figure>
  <figcaption>Example 4.4.4</figcaption>
<pre><code>\## foo
<hr />&lt;p&gt;## foo&lt;/p&gt;</code></pre>
</figure>

Contents are parsed as inlines.

<figure>
  <figcaption>Example 4.4.5</figcaption>
<pre><code># foo *bar* \*baz\*
<hr />&lt;h1&gt;foo &lt;em&gt;bar&lt;/em&gt; *baz*&lt;/h1&gt;</code></pre>
</figure>

Indentation is not allowed.

<figure>
  <figcaption>Example 4.4.6</figcaption>
<pre><code> ### foo
<hr />&lt;p&gt; ### foo&lt;/p&gt;</code></pre>
</figure>

<figure>
  <figcaption>Example 4.4.7</figcaption>
<pre><code>foo
    # bar
<hr />&lt;p&gt;foo<br />    # bar&lt;/p&gt;</code></pre>
</figure>

Headings must be separated from surrounding content by blank lines.

<figure>
  <figcaption>Example 4.4.8</figcaption>
<pre><code>---
<br />## foo<br />
---
<hr />&lt;hr /&gt;<br />&lt;h2&gt;foo&lt;/h2&gt;<br />&lt;hr /&gt;</code></pre>
</figure>

<figure>
  <figcaption>Example 4.4.9</figcaption>
<pre><code>Foo bar<br /># baz
Bar foo
<hr />&lt;p&gt;Foo bar<br /># baz<br />Bar foo&lt;/p&gt;</code></pre>
</figure>

Headings can only span one line. They cannot lazily continue.

<figure>
  <figcaption>Example 4.4.10</figcaption>
<pre><code># Hello
world!
<hr />&lt;h1&gt;Hello&lt;/h1&gt;<br />&lt;p&gt;world!&lt;/p&gt;</code></pre>
</figure>

### 4.5. Code Blocks

A <dfn>code fence</dfn> is a sequence of three consecutive backtick characters. A code block begins with a code fence and ends with code fence. The opening code block line may optionally contain text immediately following the backtick characters. This text is called the <dfn>info string</dfn> and may not contain any non-alphabetic characters.

The content of a code block may span multiple lines until the ending code fence is reached. The contents of a code block are treated as literal text, not inlines. In implementation, `<`, `>`, and `&` must be converted to `&lt;`, `&gt;`, and `&amp;` respectively to avoid conflicts with generated HTML markup.

<figure>
  <figcaption>Example 4.5.1</figcaption>
<pre><code>&grave;&grave;&grave;
&lt;
 &gt;
&grave;&grave;&grave;
<hr />&lt;pre&gt;&lt;code&gt;&amp;lt;
 &amp;gt;
&lt;/code&gt;&lt;/pre&gt;</code></pre>
</figure>

<figure>
  <figcaption>Example 4.5.2</figcaption>
<pre><code>&grave;&grave;&grave;
aaa
~~~
&grave;&grave;&grave;
<hr />&lt;pre&gt;&lt;code&gt;aaa
~~~
&lt;/code&gt;&lt;/pre&gt;</code></pre>
</figure>

The opening and closing code fences must be exactly 3 backticks long (excluding the info string):

<figure>
  <figcaption>Example 4.5.3</figcaption>
<pre><code>&grave;&grave;&grave;
content
&grave;&grave;&grave;
<hr />&lt;pre&gt;&lt;code&gt;content
&lt;/code&gt;&lt;/pre&gt;</code></pre>
</figure>

Unclosed code blocks are closed by the end of the document or parent block:

<figure>
  <figcaption>Example 4.5.4</figcaption>
<pre><code>&grave;&grave;&grave;
<hr />&lt;pre&gt;&lt;code&gt;&lt;/code&gt;&lt;/pre&gt;</code></pre>
</figure>

<figure>
  <figcaption>Example 4.5.5</figcaption>
<pre><code>&grave;&grave;&grave;
aaa
<hr />&lt;pre&gt;&lt;code&gt;aaa
&lt;/code&gt;&lt;/pre&gt;</code></pre>
</figure>

<figure>
  <figcaption>Example 4.5.6</figcaption>
<pre><code>&gt; &grave;&grave;&grave;
&gt; aaa<br />
bbb
<hr />&lt;blockquote&gt;
&lt;pre&gt;&lt;code&gt;aaa
&lt;/code&gt;&lt;/pre&gt;
&lt;/blockquote&gt;
&lt;p&gt;bbb&lt;/p&gt;</code></pre>
</figure>

A code block can have blank lines or no content:

<figure>
  <figcaption>Example 4.5.7</figcaption>
<pre><code>&grave;&grave;&grave;<br /><br />
&grave;&grave;&grave;
<hr />&lt;pre&gt;&lt;code&gt;<br />
&lt;/code&gt;&lt;/pre&gt;</code></pre>
</figure>

<figure>
  <figcaption>Example 4.5.8</figcaption>
<pre><code>&grave;&grave;&grave;
&grave;&grave;&grave;
<hr />&lt;pre&gt;&lt;code&gt;&lt;/code&gt;&lt;/pre&gt;</code></pre>
</figure>

Fences cannot be indented:

<figure>
  <figcaption>Example 4.5.9</figcaption>
<pre><code> &grave;&grave;&grave;
 aaa
aaa
&grave;&grave;&grave;
<hr />&lt;p&gt; &grave;&grave;&grave;
 aaa
aaa
&grave;&grave;&grave;&lt;/p&gt;</code></pre>
</figure>

The info string is used to specify the programming language of the code block and is rendered in the `class` attribute of the code string with prefix `language-` in accordance with the [WhatWG recommendation](https://html.spec.whatwg.org/multipage/text-level-semantics.html#the-code-element).

<figure>
  <figcaption>Example 4.5.10</figcaption>
<pre><code>&grave;&grave;&grave;ruby
def foo(x)
  return 3
end
&grave;&grave;&grave;
<hr />&lt;pre&gt;&lt;code class="language-ruby"&gt;def foo(x)
  return 3
end
&lt;/code&gt;&lt;/pre&gt;</code></pre>
</figure>

<figure>
  <figcaption>Example 4.5.11</figcaption>
<pre><code>&grave;&grave;&grave;;
&grave;&grave;&grave;
<hr />&lt;pre&gt;&lt;code class="language-;"&gt;&lt;/code&gt;&lt;/pre&gt;</code></pre>
</figure>

## 5. Container Blocks

### 5.1. Block Quotes

A <dfn>block quote marker</dfn> consists of either a `>` character followed by one space followed by content, or a single `>` character followed by a line ending. Block quote markers indicate that the following content should be nested within a block quote.

<figure>
  <figcaption>Example 5.1.0</figcaption>
<pre><code>&gt; hello
<hr />&lt;blockquote&gt;
&lt;p&gt;hello&lt;/p&gt;
&lt;/blockquote&gt;</code></pre>
</figure>

<figure>
  <figcaption>Example 5.1.1</figcaption>
<pre><code>&gt; # Foo
&gt; bar
&gt; baz
<hr />&lt;blockquote&gt;
&lt;h1&gt;Foo&lt;/h1&gt;
&lt;p&gt;bar
baz&lt;/p&gt;
&lt;/blockquote&gt;</code></pre>
</figure>

Similar to paragraphs, block quotes can lazily continue.

<figure>
  <figcaption>Example 5.1.2</figcaption>
<pre><code>&gt; # Foo
&gt; bar
baz
<hr />&lt;blockquote&gt;
&lt;h1&gt;Foo&lt;/h1&gt;
&lt;p&gt;bar
baz&lt;/p&gt;
&lt;/blockquote&gt;</code></pre>
</figure>

<figure>
  <figcaption>Example 5.1.3</figcaption>
<pre><code>&gt; bar
baz
&gt; foo
<hr />&lt;blockquote&gt;
&lt;p&gt;bar
baz
foo&lt;/p&gt;
&lt;/blockquote&gt;</code></pre>
</figure>

Laziness always applies to lines that would have been continuations of paragraphs had they been prepended with block quote markers.

<figure>
  <figcaption>Example 5.1.4</figcaption>
<pre><code>&gt; foo<br />---
<hr />&lt;blockquote&gt;
&lt;p&gt;foo<br />---&lt;/p&gt;
&lt;/blockquote&gt;</code></pre>
</figure>

<figure>
  <figcaption>Example 5.1.5</figcaption>
<pre><code>&gt; &grave;&grave;&grave;
foo
&grave;&grave;&grave;
<hr />&lt;blockquote&gt;
&lt;pre&gt;&lt;code&gt;foo
&lt;/code&gt;&lt;/pre&gt;
&lt;/blockquote&gt;</code></pre>
</figure>

A block quote can be empty.

<figure>
  <figcaption>Example 5.1.6</figcaption>
<pre><code>&gt;
<hr />&lt;blockquote&gt;
&lt;/blockquote&gt;</code></pre>
</figure>

<figure>
  <figcaption>Example 5.1.7</figcaption>
<pre><code>&gt;
&gt;  
&gt; 
<hr />&lt;blockquote&gt;
&lt;p&gt; &lt;/p&gt;
&lt;/blockquote&gt;</code></pre>
</figure>

<figure>
  <figcaption>Example 5.1.8</figcaption>
<pre><code>&gt;
&gt; foo
&gt; 
<hr />&lt;blockquote&gt;
&lt;p&gt;foo&lt;/p&gt;
&lt;/blockquote&gt;</code></pre>
</figure>

A blank line must separate block quotes.

<figure>
  <figcaption>Example 5.1.9</figcaption>
<pre><code>&gt; foo<br />
&gt; bar
<hr />&lt;blockquote&gt;
&lt;p&gt;foo&lt;/p&gt;
&lt;/blockquote&gt;
&lt;blockquote&gt;
&lt;p&gt;bar&lt;/p&gt;
&lt;/blockquote&gt;</code></pre>
</figure>

When we put these block quotes together, we get a single block quote.

<figure>
  <figcaption>Example 5.1.10</figcaption>
<pre><code>&gt; foo
&gt; bar
<hr />&lt;blockquote&gt;
&lt;p&gt;foo
bar&lt;/p&gt;
&lt;/blockquote&gt;</code></pre>
</figure>

To get a block quote with two paragraphs:

<figure>
  <figcaption>Example 5.1.11</figcaption>
<pre><code>&gt; foo
&gt; 
&gt; bar
<hr />&lt;blockquote&gt;
&lt;p&gt;foo&lt;/p&gt;
&lt;p&gt;bar&lt;/p&gt;
&lt;/blockquote&gt;</code></pre>
</figure>

Laziness requiresa blank line between a block quote and a paragraph.

<figure>
  <figcaption>Example 5.1.12</figcaption>
<pre><code>&gt; bar
baz
<hr />&lt;blockquote&gt;
&lt;p&gt;bar
baz&lt;/p&gt;
&lt;/blockquote&gt;</code></pre>
</figure>

<figure>
  <figcaption>Example 5.1.13</figcaption>
<pre><code>&gt; bar<br />
baz
<hr />&lt;blockquote&gt;
&lt;p&gt;bar&lt;/p&gt;
&lt;/blockquote&gt;
&lt;p&gt;baz&lt;/p&gt;</code></pre>
</figure>

A consequence of the laziness rule is that any number of block quote markers may be omitted on a continuation of a nested quote.

<figure>
  <figcaption>Example 5.1.14</figcaption>
<pre><code>&gt; &gt; &gt; foo
bar
<hr />&lt;blockquote&gt;
&lt;blockquote&gt;
&lt;blockquote&gt;
&lt;p&gt;foo
bar&lt;/p&gt;
&lt;/blockquote&gt;
&lt;/blockquote&gt;
&lt;/blockquote&gt;</code></pre>
</figure>

<figure>
  <figcaption>Example 5.1.15</figcaption>
<pre><code>&gt; &gt; &gt; foo
&gt; bar
&gt; &gt; baz
<hr />&lt;blockquote&gt;
&lt;blockquote&gt;
&lt;blockquote&gt;
&lt;p&gt;foo
bar
baz&lt;/p&gt;
&lt;/blockquote&gt;
&lt;/blockquote&gt;
&lt;/blockquote&gt;</code></pre>
</figure>
