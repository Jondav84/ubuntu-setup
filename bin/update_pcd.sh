#!/usr/bin/env bash
#!/usr/bin/env bash
set -euo pipefail

BASHRC="$HOME/.bashrc"

err() { printf "ERROR: %s\n" "$*" >&2; }
info() { printf "%s\n" "$*"; }

# --- prompt for a project directory path ---
read -r -p "Enter project directory path (absolute or ~): " raw_path
if [[ -z "${raw_path// }" ]]; then
  err "No path provided."
  exit 1
fi

# Expand ~ manually
proj_path="${raw_path/#\~/$HOME}"

# Basic existence check
if [[ ! -d "$proj_path" ]]; then
  err "Path is not an existing directory: $proj_path"
  exit 1
fi

# --- derive a key from path basename ---
base="$(basename "$proj_path")"

# Lowercase + convert non-alnum to underscore + trim underscores
key="$(printf "%s" "$base" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/_/g; s/^_+//; s/_+$//')"

if [[ -z "$key" ]]; then
  err "Derived key is empty; basename was: $base"
  exit 1
fi

# Ensure pcd() exists
if ! grep -q '^pcd()' "$BASHRC"; then
  err "pcd() function not found in $BASHRC"
  exit 1
fi

# Reject duplicates (case label like: "bob)")
if grep -qE "^[[:space:]]*$key\)" "$BASHRC"; then
  err "pcd entry already exists for key: $key"
  exit 1
fi

# --- insert new case into pcd() ---
# Insert just before the default (*) case in the pcd() case statement.
PCD_KEY="$key" PCD_PATH="$proj_path" perl -0777 -i -pe '
  my $k = $ENV{PCD_KEY};
  my $p = $ENV{PCD_PATH};
  s/(pcd\(\)\s*\{.*?case\s+"\$proj"\s+in.*?)(\n[ \t]*\*\)\n)/$1\n        $k)\n            cd $p\n        ;;\n$2/s
' "$BASHRC"

# --- update autocomplete opts list ---
# Append key to: local opts="..."
if grep -qE '^[[:space:]]*local opts="' "$BASHRC"; then
  if ! grep -qE "^[[:space:]]*local opts=\".*\b${key}\b" "$BASHRC"; then
    PCD_KEY="$key" perl -i -pe '
      if (/^\s*local opts="([^"]*)"/) {
        my $s = $1;
        if ($s !~ /\b\Q$ENV{PCD_KEY}\E\b/) {
          $s .= " $ENV{PCD_KEY}";
          s/^\s*local opts="[^"]*"/  local opts="$s"/;
        }
      }
    ' "$BASHRC"
  fi
else
  info "Note: _pcd_complete opts line not found; autocomplete was not updated."
fi

info "Added to pcd:"
info "  key:  $key"
info "  path: $proj_path"
info "Now run: source ~/.bashrc"
