# Writing a static site generator in bash (for sh\*ts and giggles)

The current front-end ecosystem heavily flavors static site generation as the
best way towards a performant site. Although static site generation has been
around for a while, the current surge in interest is fuelled by popular and
modern frameworks like [Hugo](https://gohugo.io),
[Gatsby](https://www.gatsbyjs.org), [11ty](https://www.11ty.dev), etc. These are
truly great products. And coupled with the JAM-stack philosophy touted by,
among others, Netlify they are great choices for getting a speedy website
up and running.

But all of these options require a heavy toolchain\*—okay, "heavy" might be a too
strong of a word in these cases save for maybe Gatsby. It got me thinking: has
anyone ever tried to make a static site generator which uses the shell? A quick
search yielded no results, so it's either never been done, or just really not a
popular choice. Let alone a wise one.

Regardless, I was curious as to whether it was possible. Last year I've been
learning and using VIM on a daily basis. This has also led me down a path of
learning all the cool shell programs most of us have installed on our machines
by default. I find great joy in learning these and the potential tricks they can
add to your workflows and there are really a lot of hidden gems in the dusty old
`man` pages to be found.

\* Please note that I don't have any issues with the aforementioned toolchains.
I snicker when I think of the "heaviest objects in the universe" joke as much as
the next guy, but really, node and npm have made groundbreaking changes in the
web landscape and I applaud them for that.

## Exploration of the problem space

Before we start clobbering our keyboard for incantations, lets think of some
requirements a minimal static site generator needs to have to make it somewhat
useful. We should at least support:

- template inheritance: I think current workflows heavily dictate a
  component-based approach. We want to have templates in which we can include
  other templates. Additionally it would be great if we could somehow extend base
  templates as well. Most grown-up template languages support these, so I think we
  should aim for the same.
- basic data and variables: things like author, title, creation and/or modified
  date for any generated page. We don't want to repeat ourselves, so these are a
  must. We might want to start with one datafile where we can house some globals
  like the site title, description and related settings. Further along the path we
  might want to think about handling folder or file-specific overrides.
- collections and pages: ideally we'd want to introduce some ✨ magic ✨ which
  allows us to handle collections (like a [blag](https://xkcd.com/148/)) and
  pages. It would be tedious to manually update a "latest posts" section for
  instance. We want the site generator to handle this.
- last, we might want to add some more magic; writing in HTML is a tad awkward.
  Writing a markdown parser in bash maybe even more so. Maybe I want to add
  support for external parsing programs, like [pandoc](https://pandoc.org)?

But there are some restrictions in our environment. We want to save people from
`brew`ing, `apt-get`ting or `apk`-ing extra tools needed for this to work. We
want to use programs which are used on practically every \*NIX system, so:
things like `cat`, `awk`, `grep`, `sed` and the shell built-ins are allowed, but other
programs like `envsubst` or `pandoc` are right out.

### Attempts, successes and caveats

Most "how-to" posts on the inter of nets feature a step-by-step explanation of
how to make something work. Here I want to do something different. Programming
doesn't consist of a happy path. There are assumptions, pitfalls and mistakes we
need to deal with on a daily basis, so I want to document these. Instead of a
how-to this is literally a journal of working on this project. I'll make
assumptions, try ugly hacks, backtrack, re-implement, and take notes of any
process or progress or lack thereof. Maybe you'll learn something from this, I
definitely did.

## Get templates, grep for includes, read the partial with sed

Let's start with the template parser. My first thought was: we need a syntax
which makes it clear that we're including a template. Nothing final yet, but
let's go with `(> path/to/file)` for now. The first task is to turn this into a
regular expression (a proper parser might be more ideal, but lets try to keep it
simple for now; it's the shell man!). Then we loop through all `*.html` files
in an arbitrary directory, see if we have matching include expressions, if so
loop through the list of files and replace the include expression with its
respective file contents.

This is where I stumbled upon something cool. If you're somewhat familiar with
`sed`, you probably know about the `s` function. But it's much, much more than
just a tool for replacing strings. It can also read files and write them to the
address space with the `r` function.

```
sed -e '/pattern/r otherfile.txt' somefile.txt
```

This expression reads `otherfile.txt` (if it exists) and pastes its contents on
the line below "pattern" in `somefile.txt`. Nifty! `sed` is even more powerful
than that; you can branch to other expressions and use labels for GOTO-kind of
functionality, but I digress. `sed` shines when doing line-based operations, but
quickly becomes tedious if you want inline operations. In the case of inline
partials for example:

```
<div>(> partial.html)</div>
<!-- sed will place contents here -->
```

That's a bit awkward. Although we can technically introduce the limitation that
any expression in our language needs to be on it's own line this isn't always
desired. Why does `sed` do this? Let's consult the manual.

> Normally, sed cyclically copies a line of input, not including its terminating
> newline character, into a pattern space, (...), applies all of the commands
> with addresses that select that pattern space, copies the pattern space to the
> standard output, appending a new-line, and deletes the pattern space.

Okay, so `sed` operates on any input line by line. What about the `r` function?
I've marked the relevant bit.

> [1addr]r file
> Copy the contents of file to the standard output _immediately before the
> next attempt to read a line of input_. If file cannot be read for any
> reason, it is silently ignored and no error condition is set.

This makes making use of `sed`'s `r` function a bit awkward. We either need to
transform the template which is currently being operated upon to always have
newlines after a include expression, or we need to remove or escape any newlines
in the partial before passing it's contents to `s`.

Or maybe I just don't know `sed` well enough.
[BRB](https://www.grymoire.com/Unix/Sed.html).

---

And I'm back. [Bruce Barnett's tutorial on
`sed`](https://www.grymoire.com/Unix/Sed.html) provided some very useful
information. Well, everything was also in the `man` page, but sometimes you need
some examples and context and, well, different wording to grok something.

One of the better `sed` incantations I came up with was the following:

```
output="$(sed -E -e "/$re/ {
  r $path
  d
}" <<< "$output")"
```

It's definitely somewhat more elegant than deleting the `$re` with `s` but
unfortunately, due to `sed`'s line-based approach, it cannot paste content
inline. We'll need another solution for this. `sed` just isn't going to work for
this use-case.

### Let's get `awk`ward!

So I've spent some days learning and tinkering. It became clear that `sed`
wasn't cut out for the task at hand. Luckily we have some more tools to our
disposal. Enter `awk`.

I use `awk` sporadically to get shell scripts to output a specific column. This
is especially handy when you're working with server logs for example. Say you
have a nginx server somewhere and you want some data on response codes: how many
successes vs errors, for example. Depending on your log format, you could do
this:

```
zcat access.log.*.gz | awk '{print $9}' | sort -r | uniq -c | sort -r
```

Which would give you the number of times a certain response code has been
returned by nginx:

```
   9199 200
   2919 500
   2888 304
   1703 429
   1425 404
    502 301
     39 206
     19 400
     10 302
      7 405
      4 403
      2 401
```

Although I've read about `awk`'s small but powerful language, I mostly used it
for scenario's like that. Boy, was I in for a treat. Just like `sed`, `awk`
operates on patterns, but it includes some more powerful functions to work with.
As an added bonus, the syntax is a _lot_ less obtuse than `sed`'s. For example,
instead of `s/pattern/replacement/flags` we get proper functions like
`sub(pattern, replacement, context)` and `gsub` (like `s/p/r/g`. Also, you
can pass along variables to be used in your `awk` script by using the `-v` flag
like thus:

```
$ TEST="awesome"
$ echo 'Hello, world!' | awk -v str="$TEST" '{ gsub(/world/, str); print }'
```

But `awk`, like `sed`, just doesn't like newlines—at least, the `awk` shipped
with macOS. If our string contains one we get an error (note the literal
newline; using a `\n` works):

```
$ TEST="awsome
"
$ echo 'Hello, world!' | awk -v str="$TEST" '{ gsub(/world/, str); print }'
awk: newline in string awesome
... at source line 1
```

After some digging, I happened upon an issue from a terraform-helper from the
hashicorp community in which user [fprimex found a super useful
workaround](https://github.com/hashicorp-community/tf-helper/issues/1#issuecomment-490656096).
Apparently `awk` keeps track of the arguments it's called with in it's `ARGV`
array. _SWEET!_ Now I think we have most of the pieces needed to make our first
requirement work: [parsing of templates](https://github.com/rombrom/rombrom.com/blob/e91795ce39d297fed88353b37ccc54ead2af892c/scripts/build).
