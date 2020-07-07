#/usr/bin/env bats

@test "input one file" {
  run scripts/build ./test/templates/partial.html
  diff -q ./test/snapshots/partial.html <(echo -e "$output")
}

@test "input two files" {
  run scripts/build \
    ./test/templates/include-inline.html \
    ./test/templates/include.html
  diff -q ./test/snapshots/input-multiple.html <(echo -e "$output")
}

@test "input glob" {
  run scripts/build ./test/templates/partials/*-include.html
  diff -q ./test/snapshots/input-glob.html <(echo -e "$output")
}

@test "input non-existent file" {
  run scripts/build /dev/null
  [[ "$status" -eq 1 ]]
}

@test "input absolute path" {
  run scripts/build /dev/null
  [[ "$output" = "File not found: /dev/null" ]]
}
