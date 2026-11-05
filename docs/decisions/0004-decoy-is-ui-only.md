# 4. The decoy vault hides the UI, not the data

**Status:** Accepted

## Context

Someone may be forced to open the app. A second passcode that shows an empty vault helps in that moment. A true second vault (separate key, separate files) would double the storage code and still leave signs on disk.

## Decision

The decoy passcode is checked against a PBKDF2 verifier that opens nothing. It starts a session in which every list is empty and adding files, folders, Web Upload, the recovery key, and full Settings are unavailable. The real files stay encrypted and untouched.

## Consequences

- Simple and hard to get wrong: the decoy never holds the vault key.
- It does not hide the existence of encrypted files from someone who inspects the phone's storage. The docs and website say so.
- The decoy must use the same lock format as the real passcode and must differ from it.
