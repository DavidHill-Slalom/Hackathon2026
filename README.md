# Salesforce Project Base

This repository is a basic Salesforce DX project structure for building custom metadata, Apex, and Lightning Web Components.

## Structure

- `force-app/main/default` — main source folder
- `force-app/main/default/classes` — Apex classes
- `force-app/main/default/triggers` — Apex triggers
- `force-app/main/default/lwc` — Lightning Web Components
- `force-app/main/default/aura` — Aura components
- `force-app/main/default/staticresources` — static resources
- `manifest/` — deployment manifests
- `config/` — scratch org definition files

## Common commands

```bash
sfdx force:org:create -f config/project-scratch-def.json -a myScratchOrg
sfdx force:source:push -u myScratchOrg
sfdx force:source:pull -u myScratchOrg
sfdx force:mdapi:deploy -d manifest/ -w 10
```

## Notes

Update the `sfdx-project.json` file and metadata folders as your project grows.
