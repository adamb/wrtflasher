Home Assistant Green Manager
Description
A specialized skill for managing a Home Assistant Green (HAOS) instance. This skill prioritizes configuration safety, Jinja2 templating accuracy, and seamless integration with the Home Assistant Supervisor.

Context & Paths
Config Root: /config/ (Accessible via Samba or SSH Add-on)

System Type: Home Assistant OS (HAOS) on a Green hub.

Key Files: configuration.yaml, automations.yaml, scripts.yaml, scenes.yaml.

Core Workflows
1. Safe YAML Editing
Before saving any changes to .yaml files, you must follow the Pre-Flight Check:

Read the target file to understand the existing structure (e.g., !include usage).

Draft the new automation or sensor code.

Mandatory Validation: Run the configuration check command via the terminal:
ha core check

Only if the check returns Command completed successfully should you proceed to reload the integration.

2. Reloading Components
Instead of a full restart (which is slow on the Green), use specific reloads when possible:

Automations: ha core reload_automations

Scripts: ha core reload_scripts

General Config: ha core reload

3. Writing Automations
When generating automations, always include:

An alias and a unique id (for UI editing compatibility).

mode: restart or queued to prevent collision.

Traces-friendly logic (clear triggers and conditions).

4. Troubleshooting
If an automation isn't working:

Check the logs: ha core logs --lines 50.

Look for specific integration errors or Jinja2 template rendering failures.

Safety Constraints
NEVER delete secrets.yaml.

NEVER initiate a ha host reboot without explicit user confirmation.

ALWAYS comment out old code instead of deleting it during a refactor so the user can revert manually if needed.
