savedcmd_lattice-bridge.mod := printf '%s\n'   lattice-bridge.o | awk '!x[$$0]++ { print("./"$$0) }' > lattice-bridge.mod
