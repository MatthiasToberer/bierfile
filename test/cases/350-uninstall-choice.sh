#!/usr/bin/env bash
# uninstall asks which lists lose the entry: all, only main, or only here
#
# It used to take the entry off every list. Keeping a program on one Mac
# while taking it out of main then meant editing Brewfiles by hand, and
# the Mac that had it only through main was never asked about it.

seed_file mini Brewfiles/main <<'EOF'
brew "wget"
brew "nmap"
EOF
system mini <<'EOF'
brew "wget"
brew "nmap"
brew "htop"
EOF
system macbook <<'EOF'
brew "wget"
brew "nmap"
EOF
assert_ok bier mini dump
assert_ok bier mini sync
assert_ok bier macbook dump
assert_ok bier macbook sync
assert_ok bier mini sync

# Nobody to ask: nothing changes.
: >"$WORK/.in"
assert_fails bier mini uninstall nmap
assert_contains "$OUT" "nobody to ask"
assert_file_has "$WORK/sys-mini" 'brew "nmap"'
assert_file_has "$(bf mini main)" 'brew "nmap"'

# Out of main, macbook keeps it.
answer m macbook
assert_ok bier mini uninstall nmap
assert_contains "$OUT" "listed in: main"
assert_file_lacks "$WORK/sys-mini" 'brew "nmap"'
assert_file_lacks "$(bf mini main)" 'brew "nmap"'
assert_file_has "$(bf mini macbook)" 'brew "nmap"'
assert_file_lacks "$(bf mini mini)" 'brew "nmap"'
assert_ok bier mini sync

# "Only here" makes no sense for what is in main.
assert_fails bier mini uninstall --here wget
assert_contains "$OUT" "take it out of main instead"
assert_file_has "$WORK/sys-mini" 'brew "wget"'

# Only here: the entry leaves this Mac's list, nobody else's.
assert_ok bier macbook sync
answer h
assert_ok bier mini uninstall htop
assert_file_lacks "$WORK/sys-mini" 'brew "htop"'
assert_file_lacks "$(bf mini mini)" 'brew "htop"'

# A Mac that had it only through main is asked, not told to record it.
assert_ok bier macbook sync
seed_file macbook Brewfiles/main <<'EOF'
brew "wget"
brew "tree"
EOF
system mini <<'EOF'
brew "wget"
brew "tree"
EOF
system macbook <<'EOF'
brew "wget"
brew "nmap"
brew "tree"
EOF
assert_ok bier macbook uninstall --from-main --keep macbook tree
assert_contains "$OUT" "stays installed here"
assert_file_has "$WORK/sys-macbook" 'brew "tree"'
assert_file_has "$(bf macbook macbook)" 'brew "tree"'
assert_ok bier macbook sync
assert_ok bier mini sync
bier mini state
assert_contains "$OUT" "DROPPED"$'\t''brew "tree"'
assert_not_contains "$OUT" "NEW"$'\t''brew "tree"'
bier mini status
assert_contains "$OUT" "No longer in main, still here"

# And a dump does not quietly adopt it.
assert_ok bier mini dump
assert_file_lacks "$(bf mini mini)" 'brew "tree"'

# prune takes care of it.
answer y
assert_ok bier mini prune
assert_file_lacks "$WORK/sys-mini" 'brew "tree"'
