#!/usr/bin/env bash
set -euo pipefail

BASHRC="$HOME/.bashrc"

err() { printf "ERROR: %s\n" "$*" >&2; }
info() { printf "%s\n" "$*"; }

read -r -p "Enter pcd key to remove (example: bob): " key
key="$(printf "%s" "$key" | tr -d '[:space:]')"

if [[ -z "$key" ]]; then
  err "No key provided."
  exit 1
fi

# Ensure pcd() exists
if ! grep -q '^pcd()' "$BASHRC"; then
  err "pcd() function not found in $BASHRC"
  exit 1
fi

# Ensure key exists (case label like: "bob)")
if ! grep -qE "^[[:space:]]*$key\)" "$BASHRC"; then
  err "pcd key not found: $key"
  exit 1
fi

# Remove the case block:
#     key)
#         ...
#     ;;
PCD_KEY="$key" perl -0777 -i -pe '
  my $k = $ENV{PCD_KEY};
  s/\n[ \t]*\Q$k\E\)\n(?:[ \t]*.*\n)*?[ \t]*;;\n/\n/s;
' "$BASHRC"

# Remove from autocomplete opts: local opts="... key ..."
if grep -qE '^[[:space:]]*local opts="' "$BASHRC"; then
  PCD_KEY="$key" perl -i -pe '
    if (/^\s*local opts="([^"]*)"/) {
      my @w = grep { length } split(/\s+/, $1);
      @w = grep { $_ ne $ENV{PCD_KEY} } @w;
      my $s = join(" ", @w);
      s/^\s*local opts="[^"]*"/  local opts="$s"/;
    }
  ' "$BASHRC"
fi

info "Removed pcd key: $key"
info "Now run: source ~/.bashrc"
