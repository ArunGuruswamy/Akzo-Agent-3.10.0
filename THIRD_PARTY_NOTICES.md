# Third-party notices

Akzo SDD Agent — Developed and maintained by Arun RG

## Bundled third-party material
None. All agent instructions, workflow modules, templates, scripts, and documentation in this repository are original.

## Tools used at run time (not bundled or redistributed)
The scripts call these tools only if they are already installed on the user's machine. They are governed by their own licenses.

| Tool | Used by | Required |
|------|---------|----------|
| Windows PowerShell / PowerShell | `scripts/*.ps1`, `copilot/modules/investigate/scripts/akzo.ps1` | Yes |
| Git | installer repository check, helper `state`/`task` commands | Yes |
| Python with the `graphify` package | helper `graph` command | No (optional) |
| .NET Framework Windows Forms and UI Automation (part of Windows) | launchers (`*.cmd`, `Install-MasterAgent.ps1`, `Start-Development.ps1`), helper `pick` file dialog, `scripts/test-gui.ps1` | Yes for the windows; `-NoGui` and `-Source` work without them |
| `pdftotext` (Poppler) | helper `pick` for `.pdf` requirement files | No (optional) |
| GitHub Copilot in VS Code or Visual Studio 2026 | runs the agent | Yes |
| SonarQube Server or SonarQube Cloud (Web API), SonarQube MCP server, SonarQube for IDE, Sonar analyzers and scanners | helper `sonar` command (read-only Web API queries), agent section 6a | No (optional; used only when the developer has configured them) |

SonarQube and SonarQube Cloud are products of SonarSource. The integration calls their public Web API and tools; no SonarSource code, rules text, or plugin content is included.

Update this file if any third-party code or content is added, keeping all required license and attribution notices.

## Design references (not bundled, not used at run time)
Tree-sitter, Continue, Aider (repository maps), and Microsoft Semantic Kernel / Microsoft Agent Framework were studied as design references for incremental indexing, context retrieval, and tool orchestration. No code, text, grammar, or dependency from them is included; the symbol extraction, ranking, memory, and security controls in this package are original implementations in Windows PowerShell. Adopting any of them later would require a licence, supply-chain, and security review and an update to this file.