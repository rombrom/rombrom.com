#/usr/bin/env bats

@test "input one file" {
  snapshot="$(<./test/snapshots/partial.html)"
  run scripts/build ./test/templates/partial.html
  diff <(echo -e "$snapshot") <(echo -e "$output")
}

@test "input two files" {
  snapshot="$(<./test/snapshots/input-multiple.html)"
  run scripts/build \
    ./test/templates/include-inline.html \
    ./test/templates/include.html
  diff <(echo -e "$snapshot") <(echo -e "$output")
}

@test "input glob" {
  snapshot="$(<./test/snapshots/input-glob.html)"
  run scripts/build ./test/templates/partials/*.html
  diff <(echo -e "$snapshot") <(echo -e "$output")
}

@test "input non-existent file" {
  run scripts/build /dev/null
  [[ "$status" -eq 1 ]]
  [[ "$output" = "File not found: /dev/null" ]]
}
