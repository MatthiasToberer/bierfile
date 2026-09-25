[Docs](../../README.md) › [Commands](README.md)

# bier take — gone

`bier take` moved entries between `main` and the Macs' own lists. With
[groups](../../concepts/groups.md), software goes to All Macs or to a
group, and [`bier place`](place.md) says where it belongs:

```sh
bier list                          # what is where, and what is not assigned
bier place <package> --all         # for All Macs
bier place <package> --on <group>  # for groups
```

`bier take` now says the same and changes nothing.
