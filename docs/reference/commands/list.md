[Docs](../../README.md) › [Commands](README.md)

# bier list

```
bier list
bier ls
```

Everything bier keeps, in one view: what All Macs have, what each group
has on top, what each Mac installed that nobody assigned, each app's
shared settings next to it, and the files shared on their own.

```
All Macs
  handbrake-app                    app        settings: Application Support
  rectangle                        app        settings: Preferences.plist
  bat                              formula    settings: config
  wget                             formula

Group laptops (mini, macbook)
  jq                               formula    settings: config (only laptops)
  WireGuard                        App Store

Not assigned, installed on mini (this Mac)
  font-meslo-lg-nerd-font          app

Files
  ~/.zshrc
  ~/.config/nvim/

Settings of apps on no list
  Foo                              settings: Foo
```

The last part shows settings added with `bier vault add --app` for an
app that is on no list — added by hand, or the app has left.

Changes nothing. To give an entry to All Macs or a group:
[`bier place`](place.md). What waits
to go out or has arrived: [`bier status`](status.md).
