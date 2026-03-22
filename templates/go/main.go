// Piqley plugin: __PLUGIN_NAME__
package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
)

type PluginPayload struct {
	Hook            string                 `json:"hook"`
	ImageFolderPath string                 `json:"imageFolderPath"`
	PluginConfig    map[string]interface{} `json:"pluginConfig"`
	Secrets         map[string]string      `json:"secrets"`
	DryRun          bool                   `json:"dryRun"`
}

type Result struct {
	Type    string  `json:"type"`
	Success bool    `json:"success"`
	Error   *string `json:"error"`
}

func main() {
	input, err := io.ReadAll(os.Stdin)
	if err != nil {
		writeError(fmt.Sprintf("failed to read stdin: %v", err))
		os.Exit(1)
	}

	var payload PluginPayload
	if err := json.Unmarshal(input, &payload); err != nil {
		writeError(fmt.Sprintf("failed to parse payload: %v", err))
		os.Exit(1)
	}

	// TODO: Implement plugin logic for each hook
	// Available hooks: pre-process, post-process, publish, post-publish

	result := Result{Type: "result", Success: true, Error: nil}
	out, _ := json.Marshal(result)
	fmt.Println(string(out))
}

func writeError(msg string) {
	result := Result{Type: "result", Success: false, Error: &msg}
	out, _ := json.Marshal(result)
	fmt.Println(string(out))
}
