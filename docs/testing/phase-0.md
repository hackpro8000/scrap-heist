# Phase 0 test checklist

## Boot order

1. Run `rojo serve` and connect from Studio.
2. Press **Play** (solo).
3. In the Output window, check for:
   - `[Server] booted 0 module(s)`
   - `[Client] booted 0 module(s)`
4. Check there are no errors or warnings from `Server` or `Client`.

No services or controllers exist yet, so the boot lines report 0 modules.
Each later phase adds an `init` and `start` line per module, in the order
listed in `src/server/init.server.luau` and `src/client/init.client.luau`.

## Packages

1. In the Explorer, check `ServerStorage.ServerPackages.ProfileStore` exists.
