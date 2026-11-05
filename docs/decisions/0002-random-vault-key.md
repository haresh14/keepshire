# 2. One random vault key, wrapped by each way in

**Status:** Accepted

## Context

If files were encrypted directly with a key derived from the passcode, every passcode change would rewrite every file: slow for large vaults, and a crash part-way through could leave files under two different keys. Face ID and a recovery key would each need the passcode too.

## Decision

A random 256-bit vault key encrypts all files, thumbnails, and metadata. It never changes. The Keychain stores it only in wrapped form: AES-GCM under a PBKDF2 key from the passcode, a Secure Enclave copy for Face ID, and AES-GCM under a key from the recovery key. The passcode itself is never stored.

## Consequences

- Changing the passcode re-wraps 32 bytes in one Keychain update; it is instant and cannot half-finish.
- New ways in (Face ID, recovery key) are just another wrap of the same key.
- Losing every wrap means the files are unreadable; there is no other copy.
- Older vaults whose key was derived from the passcode adopt that key as their vault key on first unlock, without rewriting files.
