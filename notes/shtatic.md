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
