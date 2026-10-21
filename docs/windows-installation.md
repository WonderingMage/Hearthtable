# Windows installation and publisher signing

Future Lite releases use `Hearthtable-Lite-VERSION-Windows.zip`. Extract it and run the included `Hearthtable-Lite-VERSION-Setup.exe`. Setup requires administrator approval because the owner requested **Program Files (x86)**. The app is still x64 and requires 64-bit Windows. Setup creates desktop and Start Menu shortcuts, installs the player program and a clean versioned source copy at `Source\VERSION`, and supplies an uninstaller.

Campaigns, scene caches, Settings updates and rollback backups stay at `%APPDATA%\Godot\app_userdata\Hearthtable Lite`. Setup and uninstall never remove this folder. To edit source, copy its versioned folder to a writable development directory. Installing an app under Program Files does not grant ordinary users write access to its source.

## Building and checking

The Linux builder `tools/release_lite.py --validation --output /new/output` requires clean source, pins/checks official Godot 4.5.1, exports the application and matching `.hearthupdate`, exercises actual networking/portable/update restoration, and creates a SHA-256-bound `git archive` source companion. `--tag lite-vVERSION` additionally requires the exact clean tag. Direct `--publish` is refused: publication must include the Windows installer stage.

On Windows, `tools/package_installer.ps1 -Build PATH -Validate` verifies payload/source hashes and uses Inno Setup 6 to compile the installer. Native validation runs only on a fresh GitHub-hosted VM and refuses existing app or user data. It checks the installed EXE, source, desktop/Start Menu targets, native headless throne imports in offline/lobby/table modes, uninstall and preservation of synthetic AppData. It does not establish hardware GUI/audio performance or external internet play.

Manual **Windows release** workflow dispatch with `tag=lite-vVERSION`, `build_only=true`, `windows_probe=false` builds the current branch without creating a tag or publishing. Its `Hearthtable-Lite-Windows` artifact contains the installer ZIP, Settings update, manifest and checksums. Ordinary branch pushes do not publish. A requested release uses a new immutable tag and both Linux and Windows jobs before publishing four assets: ZIP, `.hearthupdate`, checksums and manifest. Published 1.0.0/1.0.1 assets remain unchanged.

## Unknown publisher and SmartScreen

An installer ZIP alone cannot establish a verified publisher. Windows needs a trusted Authenticode signature on the setup/app; a self-signed certificate is not trusted on other people's PCs. `AppPublisher=WonderingMage` is descriptive metadata, not a verified identity. A trusted signature also does not guarantee that SmartScreen, antivirus or organizational policies will allow every new download.

The optional certificate-store provider signs the app before packaging, signs the Inno uninstaller through its compiler hook, signs the finished setup, uses SHA-256 and a trusted timestamp, and verifies the resulting signatures. It never disables Windows checks or creates a self-signed production identity. Without configured signing, builds remain unsigned and the manifest explicitly records `installer.signed=false`.

For an existing trusted certificate/private key usable in the Windows certificate store, set `HEARTHTABLE_SIGNING_THUMBPRINT` locally. GitHub-hosted runners optionally accept repository secrets `WINDOWS_SIGNING_PFX_BASE64` and `WINDOWS_SIGNING_PFX_PASSWORD` for an existing exportable identity. The workflow imports it into the current runner's certificate store, removes the temporary PFX immediately and removes the imported signing certificate afterward. Never commit certificates/passwords or send private keys in chat. Modern commercial signing identities often use hardware/cloud keys and cannot be exported as PFX; choose their supported service integration instead.

### Can signing be free?

The [SignPath Foundation](https://signpath.org/) offers free trusted signing for accepted open-source projects. Acceptance is discretionary; being public on GitHub is not sufficient. Its published [conditions](https://signpath.org/terms) include an OSI-approved license for all components, active maintenance, existing public releases, verifiable builds, project reputation, MFA, named review/approval roles, an accurate privacy/signing policy and manual approval of each signing request. Foundation signatures identify **SignPath Foundation** as the publisher. Review the current [application instructions](https://signpath.org/apply) yourself before agreeing to the service.

Hearthtable's original source is MIT-licensed in `LICENSE.txt`, with existing third-party notices and an older retained root `LICENSE`. No licenses or ownership have been changed here. The project owner must confirm all bundled content meets the service's criteria, including the Godot export-template packaging, and apply/accept its terms. Once approved, organization/project/policy identifiers and the service's verified GitHub integration are needed. No application was submitted, signing policy/approval was invented, or SignPath sponsorship claimed by this change. The current certificate provider does not pretend to be a configured SignPath integration.

The Foundation website was inaccessible from the cloud proxy during this work; its official public website source was checked at [SignPath/fdn-website](https://github.com/SignPath/fdn-website/blob/main/docs/terms.md). Recheck the live terms when applying. A paid trusted certificate or signing service is an alternative if the project is not accepted; no purchase or account enrollment is automatic.
