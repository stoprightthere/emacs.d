#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '[vterm-sgr2] %s\n' "$*"
}

die() {
  printf '[vterm-sgr2] ERROR: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1 || die "Missing required command: $cmd"
}

jobs_count() {
  if command -v nproc >/dev/null 2>&1; then
    nproc
  elif command -v getconf >/dev/null 2>&1; then
    getconf _NPROCESSORS_ONLN
  else
    printf '2\n'
  fi
}

EMACS_DIR="${EMACS_DIR:-$HOME/.emacs.d}"
ELPA_DIR="${ELPA_DIR:-$EMACS_DIR/elpa}"
PATCH_FILE="${PATCH_FILE:-$EMACS_DIR/local-lisp/vterm-libvterm-faint.patch}"

require_cmd cmake
require_cmd make
require_cmd perl
require_cmd git

vterm_dir="$(
  find "$ELPA_DIR" -mindepth 1 -maxdepth 1 -type d -name 'vterm-[0-9]*' \
    | sort -V | tail -n 1
)"
[[ -n "${vterm_dir:-}" ]] || die "No vterm package found under $ELPA_DIR"

build_dir="$vterm_dir/build"
libvterm_dir="$build_dir/libvterm-prefix/src/libvterm"
jobs="$(jobs_count)"

log "Target: $vterm_dir"

if [[ ! -f "$build_dir/Makefile" ]]; then
  log "Configuring build directory"
  cmake -S "$vterm_dir" -B "$build_dir"
fi

if [[ ! -d "$libvterm_dir/.git" ]]; then
  log "Bootstrapping vendored libvterm source tree"
  cmake --build "$build_dir" --target libvterm
fi

[[ -f "$PATCH_FILE" ]] || die "Patch file not found: $PATCH_FILE"

if grep -q 'VTERM_ATTR_FAINT' "$libvterm_dir/include/vterm.h"; then
  log "libvterm SGR 2 patch already present"
else
  log "Applying libvterm SGR 2 patch"
  (cd "$libvterm_dir" && git apply --whitespace=nowarn "$PATCH_FILE")
fi

elisp_h="$vterm_dir/elisp.h"
elisp_c="$vterm_dir/elisp.c"
vterm_module_c="$vterm_dir/vterm-module.c"

[[ -f "$elisp_h" ]] || die "Missing file: $elisp_h"
[[ -f "$elisp_c" ]] || die "Missing file: $elisp_c"
[[ -f "$vterm_module_c" ]] || die "Missing file: $vterm_module_c"

if ! grep -q 'extern emacs_value Qlight;' "$elisp_h"; then
  perl -0777 -i -pe \
    's/(extern emacs_value Qbold;\n)/$1extern emacs_value Qlight;\n/s' \
    "$elisp_h"
fi
grep -q 'extern emacs_value Qlight;' "$elisp_h" \
  || die "Failed to patch $elisp_h"

if ! grep -q '^emacs_value Qlight;$' "$elisp_c"; then
  perl -0777 -i -pe \
    's/(emacs_value Qbold;\n)/$1emacs_value Qlight;\n/s' \
    "$elisp_c"
fi
grep -q '^emacs_value Qlight;$' "$elisp_c" \
  || die "Failed to patch $elisp_c"

if ! grep -q 'a->attrs\.faint == b->attrs\.faint' "$vterm_module_c"; then
  perl -0777 -i -pe \
    's/(equal = equal && \(a->attrs\.bold == b->attrs\.bold\);\n)/$1  equal = equal && (a->attrs.faint == b->attrs.faint);\n/s' \
    "$vterm_module_c"
fi

if ! grep -q 'emacs_value weight = Qnil;' "$vterm_module_c"; then
  perl -0777 -i -pe \
    's@  emacs_value bold =\n      cell->attrs\.bold && !term->disable_bold_font \? Qbold : Qnil;\n@  emacs_value weight = Qnil;\n  if (!term->disable_bold_font) {\n    if (cell->attrs.bold) {\n      weight = Qbold;\n    } else if (cell->attrs.faint) {\n      weight = Qlight;\n    }\n  }\n@s' \
    "$vterm_module_c"
fi

if grep -q 'if (bold != Qnil)' "$vterm_module_c"; then
  perl -0777 -i -pe \
    's/if \(bold != Qnil\)\n    props\[props_len\+\+\] = Qweight, props\[props_len\+\+\] = bold;/if (weight != Qnil)\n    props[props_len++] = Qweight, props[props_len++] = weight;/s' \
    "$vterm_module_c"
fi

if ! grep -q 'Qlight = env->make_global_ref(env, env->intern(env, "light"));' "$vterm_module_c"; then
  perl -0777 -i -pe \
    's/(Qbold = env->make_global_ref\(env, env->intern\(env, "bold"\)\);\n)/$1  Qlight = env->make_global_ref(env, env->intern(env, "light"));\n/s' \
    "$vterm_module_c"
fi

grep -q 'emacs_value weight = Qnil;' "$vterm_module_c" \
  || die "Failed to patch weight handling in $vterm_module_c"
grep -q 'a->attrs\.faint == b->attrs\.faint' "$vterm_module_c" \
  || die "Failed to patch cell comparison in $vterm_module_c"
grep -q 'Qlight = env->make_global_ref(env, env->intern(env, "light"));' "$vterm_module_c" \
  || die "Failed to patch symbol init in $vterm_module_c"

log "Rebuilding vendored libvterm with PIC"
make -C "$libvterm_dir" clean
make -C "$libvterm_dir" "CFLAGS=-fPIC" "LDFLAGS=-static" -j"$jobs"

log "Rebuilding vterm-module.so"
make -C "$build_dir" vterm-module -j"$jobs"

log "Done"
