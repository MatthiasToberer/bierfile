[Docs](../../README.md) › [Commands](README.md)

# bier list

```
bier list
bier ls
```

Everything bier keeps, in one view: what every Mac installs (`main`),
what only this Mac and each other Mac has on top, each app's shared
settings next to it, and the files shared on their own.

```
Every Mac (main)
  handbrake-app                    app        settings: Application Support
  rectangle                        app        settings: Preferences.plist
  bat                              formula    settings: config
  wget                             formula

Only on mini (this Mac)
  jq                               formula    settings: config (only mini)

Only on macbook
  font-meslo-lg-nerd-font          app
  WireGuard                        App Store

Files
  ~/.zshrc
  ~/.config/nvim/

Settings of apps on no list
  Foo                              settings: Foo
```

The last part shows settings added with `bier vault add --app` for an
app that is on no list — added by hand, or the app has left.

Changes nothing. To adopt an entry: [`bier take`](take.md). What waits
to go out or has arrived: [`bier status`](status.md).
