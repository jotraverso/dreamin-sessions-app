---
applyTo: "**"
---

# General Salesforce Development Requirements

- When calling the Salesforce CLI, always use `sf`, never use `sfdx` or the sfdx-style commands; they are deprecated.
- Use `https://github.com/salesforcecli/mcp` MCP tools (if available) before Salesforce CLI commands.
- When creating new objects, classes and triggers, always create XML metadata files for objects (.object-meta.xml), classes (.cls-meta.xml) and triggers (.trigger-meta.xml).
