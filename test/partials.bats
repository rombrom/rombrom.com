#!/usr/bin/env bats

@test "include a partial" {
  snapshot="$(<./test/snapshots/include.html)"
  run scripts/build ./test/templates/include.html
  diff <(echo -e "$snapshot") <(echo -e "$output")
}

@test "include a child partial" {
  snapshot="$(<./test/snapshots/include-subdir.html)"
  run scripts/build ./test/templates/include-subdir.html
  diff <(echo -e "$snapshot") <(echo -e "$output")
}

@test "include a child partial with a sibling partial" {
  snapshot="$(<./test/snapshots/include-nested.html)"
  run scripts/build ./test/templates/include-nested.html
  diff <(echo -e "$snapshot") <(echo -e "$output")
}

@test "include a child partial with a parent partial" {
  snapshot="$(<./test/snapshots/include-nested-parent.html)"
  run scripts/build ./test/templates/include-nested-parent.html
  diff <(echo -e "$snapshot") <(echo -e "$output")
}

@test "include a glob" {
  snapshot="$(<./test/snapshots/include-glob.html)"
  run scripts/build ./test/templates/include-glob.html
  diff <(echo -e "$snapshot") <(echo -e "$output")
}

@test "include a partial inline" {
  snapshot="$(<./test/snapshots/include-inline.html)"
  run scripts/build ./test/templates/include-inline.html
  diff <(echo -e "$snapshot") <(echo -e "$output")
}
