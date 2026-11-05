# 3. Recovery key for a forgotten passcode

**Status:** Accepted

## Context

Without a way back, a forgotten passcode loses every file. Options considered:

1. **Recovery key** written down by the user.
2. **Unlock with the iPhone's own passcode** through the Secure Enclave.
3. **Secret synced through iCloud Keychain.**
4. Email or SMS reset, or security questions.

## Decision

Use a recovery key (option 1). It is 24 characters of Crockford base32 (120 random bits) that wraps the vault key in its own Keychain item. It is shown once and saved only after the user types its last four characters back. It is optional, offered after setup and after unlock until declined.

## Why not the others

- **iPhone passcode:** anyone who knows the phone's passcode, often a partner or family member, could open the vault, which defeats a common reason to use it.
- **iCloud Keychain:** anyone with the Apple ID and device passcode could recover, and it adds a cloud dependency ([0001](0001-on-device-only.md)).
- **Email, SMS, or questions:** need a server holding a key, or are easy to guess.

## Consequences

- No one but the holder of the key can recover; losing both the passcode and the key still loses the files.
- Recovery attempts share the passcode lockout.
- The recovery wrap is separate from the passcode wrap, so passcode changes never remove it.
- The decoy session never sees it.
