/**
 * Piqley plugin: __PLUGIN_NAME__
 */

interface PluginPayload {
  hook: string;
  imageFolderPath: string;
  pluginConfig: Record<string, unknown>;
  secrets: Record<string, string>;
  dryRun: boolean;
}

async function main(): Promise<void> {
  const input = await readStdin();
  const payload: PluginPayload = JSON.parse(input);

  // TODO: Implement plugin logic for each hook
  // Available hooks: pre-process, post-process, publish, post-publish

  console.log(JSON.stringify({ type: "result", success: true, error: null }));
}

function readStdin(): Promise<string> {
  return new Promise((resolve) => {
    let data = "";
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (chunk: string) => (data += chunk));
    process.stdin.on("end", () => resolve(data));
  });
}

main().catch((err) => {
  console.log(
    JSON.stringify({ type: "result", success: false, error: String(err) })
  );
  process.exit(1);
});
