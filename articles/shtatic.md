# Writing a static site generator in bash (for shits and giggles)

The current front-end ecosystem heavily flavors static site generation as the
best way towards a performant site. Although static site generation has been
around for a while, the current surge in interest is fuelled by popular and
modern frameworks like Hugo, Gatsby, 11ty, etc. These are truly great products.
And coupled with the JAM-stack philosophy touted by, among others, Netlify they
are great choices for getting a speedy website up and running.

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

- template inheritance: I think current workflows heavily dictate a component-based approach. We want to have templates in which we can include other templates. Additionally it would be great if we could somehow extend base templates as well. Most grown-up template languages support these, so I think we should aim for the same.
- basic data and variables: things like author, title, creation and/or modified date for any generated page. We don't want to repeat ourselves, so these are a must. We might want to start with one datafile where we can house some globals like the site title, description and related settings. Further along the path we might want to think about handling folder or file-specific overrides.
- collections and pages:

But there are some restrictions in our environment. We want to save people from
`brew`ing, `apt-get`ting or `apk`-ing extra tools needed for this to work. We
want to use programs which are used on practically every \*NIX system, so:
things like `cat`, `awk`, `grep`, `sed` and the shell built-ins are allowed, but other
programs like `envsubst` or `pandoc` are right out.

## Attempts, successes and caveats

Most "how-to" posts on the inter of nets feature a step-by-step explanation of
how to make something work. Here I want to do something different. Programming
doesn't consist of a happy path. There are assumptions, pitfalls and mistakes we
need to deal with on a daily basis, so I want to document these. Instead of a
how-to this is literally a journal of working on this project. I'll make
assumptions, try ugly hacks, backtrack, re-implement, and take notes of any
process or progress or lack thereof. Maybe you'll learn something from this, I
definitely did.

### Get templates, grep for includes, read the partial with sed

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
functionality, but I digress.

Let's see what we can come up with.

```
#!/usr/bin/env sh

RE_PARTIAL='\(>[[:blank:]]*(.+[[:blank:]]*)\)'

parse_file() {
  local output="$1"

  # loop through unique filenames read from the expression:
  # (> path/to/file)
  # 1. grep for our pattern and only list the result (-o)
  # 2. remove the expression syntax and keep the file path
  # 3. make sure we have no duplicates
  for partial_file in $(grep -oE "$RE_PARTIAL" <<< "$output" \
    | sed -E "s/$RE_PARTIAL/\1/" \
    | uniq); do

    # create a RegEx for this specific file
    local re="\(>[[:blank:]]*$partial_file[[:blank:]]*\)"

    # let sed operate on the $output where we
    # 1. read the contents of $partial_file
    # 2. remove the include expression
    output=$(sed -E \
      -e"/$re/r $partial_file" \
      -e "s/$re//g" <<< "$output")

  done;

  # and return the output
  echo "$output"
}

main() {
  local files="$1"
  for template_file in "$files"; do
    template_content=$(<$template_file)
    parse_file "$template_content"
  done
}

if [[ -z "$1" ]]; then
  echo "Missing argument 1: filepath or glob." 1>&2
  exit 2
fi

main "$1"
```

So this works, but it has a few issues. We can't have includes in subdirectories
or nested includes. The partials can only be included at the top-level, e.g. the
'templates'. This is because 1) the `$re` we construct isn't escaped, so `sed`
throws an error when encountering a `/` in `$partial_file`. Let's escape this:

```
diff --git a/scripts/build b/scripts/build
index aaa6c2b..de2dc22 100755
--- a/scripts/build
+++ b/scripts/build
@@ -2,0 +3 @@
+RE_ESCAPE='[]\/$*.^[]'
@@ -15 +16,2 @@ parse_file() {
-    local re="\(>[[:blank:]]*$partial_file[[:blank:]]*\)"
+    local esc_partial_file=$(sed -E "s/$RE_ESCAPE/\\\&/g" <<< "$partial_file")
+    local re="\(>[[:blank:]]*$esc_partial_file[[:blank:]]*\)"
```

This solves includes in subdirectories but any self-respecting template parser
would allow for arbitrary levels of nesting. Say we have a template in
`partials/a.html` with an include `(> b.html)`, we would expect it to insert the
contents of `partials/b.html`.

This is where I encountered some hurdles. Ideally we'd just call the
`parse\_file` function recursively on the template. There are a few ways we can
do this. I opted for allowing `parse_file` to read from STDIN:

```
diff --git a/scripts/build b/scripts/build
index de2dc22..2fb7487 100755
--- a/scripts/build
+++ b/scripts/build
@@ -7 +7 @@ parse_file() {
-  local output="$1"
+  local output="${1:-$(</dev/stdin)}"
@@ -24 +24,2 @@ parse_file() {
-      -e "s/$re//g" <<< "$output")
+      -e "s/$re//g" <<< "$output" \
+      | parse_file)
```

This allows include expressions in partials to be parsed, but it fails silently
for the scenario described above. We still need to use file paths in include
expressions relative to the current working directory. There might be a few
solutions we could try. Lets first do some housekeeping. `parse_file` is a
bit of a strange function. I'd expect the parameter to be a file, but it's a
string, so:

```
diff --git a/scripts/build b/scripts/build
index 2fb7487..3b545ce 100755
--- a/scripts/build
+++ b/scripts/build
@@ -6 +6 @@ RE_PARTIAL='\(>[[:blank:]]*(.+[[:blank:]]*)\)'
-parse_file() {
+parse() {
@@ -25 +25 @@ parse_file() {
-      | parse_file)
+      | parse)
@@ -36,2 +36 @@ main() {
-    template_content=$(<$template_file)
-    parse_file "$template_content"
+    parse < "$template_file"
```

Awesome. Now how do we get `sed` to read from a file referenced in a
subdirectory? I think we have two options. Modify `parse` to have a subdirectory
as an argument which we prepend to the `$partial_file`, or `cd` into the
directory of the currently parsed partial. Note that `sed`'s read file function
fails silently. This seems better than checking in bash whether the subdirectory
exists and, if so, `cd` into it. Adding an argument to `parse`, however, is now
a bit awkward, since we defaulted the first argument to read from `/dev/stdin`.
Let's just make this the default. Either we pipe content to this function or
read from a file using the shell's read from file functionality:

```
diff --git a/scripts/build b/scripts/build
index 3b545ce..cfaf717 100755
--- a/scripts/build
+++ b/scripts/build
@@ -7 +7,2 @@ parse() {
-  local output="${1:-$(</dev/stdin)}"
+  local output="$(</dev/stdin)"
+  local dir="${1:-$PWD}"
@@ -21,0 +23 @@ parse() {
+    # 3. recursively parse includes in $partial_file
@@ -23 +25 @@ parse() {
-      -e"/$re/r $partial_file" \
+      -e"/$re/r $dir/$partial_file" \
@@ -25 +27 @@ parse() {
-      | parse)
+      | parse "$(dirname "$partial_file")")
```

Wham! Bam! Thank you, mam! We can recursively walk templates and partials!
However, this only works properly when we put the include expressions on it's
own line:

```
<div>(> partial.html)</div>
<!-- sed will place contents here -->
```

That's a bit awkward. Although we can technically introduce the limitation that
any expression in our language needs to be on it's own line this isn't always
desired. Why does `sed` do this? Let's consult the manual.

> Normally, sed cyclically copies a line of input, not including its terminating newline character, into a pattern space, (...), applies all of the commands with addresses that select that pattern space, copies the pattern space to the standard output, appending a new-line, and deletes the pattern space.

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

Or maybe I just don't know `sed` well enough. BRB.
