"""Piqley plugin: __PLUGIN_NAME__"""

import json
import sys


def main():
    payload = json.loads(sys.stdin.read())
    hook = payload.get("hook", "")
    image_folder = payload.get("imageFolderPath", "")
    dry_run = payload.get("dryRun", False)

    # TODO: Implement plugin logic for each hook
    # Available hooks: pre-process, post-process, publish, post-publish

    print(json.dumps({"type": "result", "success": True, "error": None}))


if __name__ == "__main__":
    main()
