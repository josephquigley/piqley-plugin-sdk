# ``PiqleyPluginSDK``

Build plugins for piqley's image processing pipeline.

## Overview

The PiqleyPluginSDK handles communication with piqley so your plugin can focus on business logic. It reads requests from stdin, dispatches them to your ``PiqleyPlugin/handle(_:)`` method, and writes responses to stdout.

A plugin receives a ``PluginRequest`` for each pipeline stage invocation. The request contains the hook, image folder path, config, secrets, state from upstream plugins, and runtime flags like ``PluginRequest/dryRun``.

## Topics

### Essentials

- ``PiqleyPlugin``
- ``PluginRequest``
- ``PluginResponse``

### Hooks

- ``HookRegistry``
- ``StandardHook``

### State

- ``ResolvedState``
- ``StateKey``

### Articles

- <doc:DryRun>
