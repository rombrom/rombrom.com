#!/usr/bin/env bats

@test "include a partial" {
  run scripts/build ./test/templates/include.html
  diff -q ./test/snapshots/include.html <(echo -e "$output")
}

@test "include a child partial" {
  run scripts/build ./test/templates/include-subdir.html
  diff -q ./test/snapshots/include-subdir.html <(echo -e "$output")
}

@test "include a child partial with a sibling partial" {
  run scripts/build ./test/templates/include-nested.html
  diff -q ./test/snapshots/include-nested.html <(echo -e "$output")
}

@test "include a child partial with a parent partial" {
  run scripts/build ./test/templates/include-nested-parent.html
  diff -q ./test/snapshots/include-nested-parent.html <(echo -e "$output")
}

@test "include a glob" {
  run scripts/build ./test/templates/include-glob.html
  diff -q ./test/snapshots/include-glob.html <(echo -e "$output")
}

@test "include a partial inline" {
  run scripts/build ./test/templates/include-inline.html
  diff -q ./test/snapshots/include-inline.html <(echo -e "$output")
}

@test "include a large partial" {
  run scripts/build ./test/templates/include-large-file.html
  diff -q ./test/snapshots/include-large-file.html <(echo -e "$output")
}

@test "include a partial with potential backreferences" {
  run scripts/build ./test/templates/include-backref.html
  diff -q ./test/snapshots/include-backref.html <(echo -e "$output")
}

@test "include a non-existing partial" {
  run scripts/build ./test/templates/include-non-existing.html
  diff -q ./test/snapshots/include-non-existing.html <(echo -e "$output")
}
