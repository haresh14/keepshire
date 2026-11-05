# 1. Everything stays on the device

**Status:** Accepted

## Context

People use Keepshire for files they do not want anyone else to see. Any server, account, or cloud copy is another place those files, or facts about them, could leak from.

## Decision

Keepshire has no account, no server, no cloud sync, no analytics, and no third-party SDKs. Vault files and the database are excluded from iCloud and computer backups. Keychain items are `ThisDeviceOnly`. The only network feature is Web Upload, a server that runs on the phone and is reachable only on the local Wi-Fi.

## Consequences

- The App Store privacy label is "Data Not Collected".
- There is no remote password reset; recovery has to work on the device alone ([0003](0003-recovery-key.md)).
- A lost or replaced phone means a lost vault. Restoring a backup to a new phone starts an empty vault.
- Moving files between devices goes through Web Upload or the Share sheet.
