# Bier Agent

The Swift `bier-agent` is part of Bierfile and is installed locally by
`install.sh`. `bier peer offer` and `bier peer pair` connect two normally
installed Macs without an SSH login. `bier peer install` remains available
for remotely bootstrapping a Mac over SSH.

The agent has a deliberately narrow HTTP interface. It announces itself on
`_bier-agent._tcp` and provides a health endpoint and an authenticated
peer hello. A hello carries a peer name, timestamp, nonce
and OpenSSH signature; the agent checks it against the peer key registered by
pairing or remote installation and rejects replayed requests. The data
protocol is restricted to Bier data and Git history; it is not a remote shell.

Build and test it on macOS:

```sh
./Tests/BierAgentTests/test.sh
```
