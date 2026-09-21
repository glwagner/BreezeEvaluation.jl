Observed on pcluster during finalization of array7331 (2026-09-21 UTC):

```sh
env SHLVL=0 bash --noprofile --norc -l -c 'printf "probe_SHLVL=%s\n" "$SHLVL"; set -e; printf "probe_explicit_exit=0\n"; exit 0'
```

Output: `probe_SHLVL=1`, `probe_explicit_exit=0`; the outer shell observed exit status1. A separate `/usr/bin/clear_console -q` also returned1 in the noninteractive SSH session.

Read-only inspection of the user's existing `~/.bash_logout` showed:

```sh
if [ "$SHLVL" = 1 ]; then
    [ -x /usr/bin/clear_console ] && /usr/bin/clear_console -q
fi
```

The scientific wrapper uses `#!/bin/bash -l` and `set -euo pipefail`. It recorded childexit0, printed the success sentinel, then executed `exit "$code"`. Thus the login-shell teardown provides a reproduced mechanism for schedulerexit1 after successful physics. Actual batchSHLVL was not recorded, so attribution to this mechanism for7331 remains an inference. No shell profile or frozen wrapper was changed by this investigation.

Scientific admission is independent: both childexit records were hashed and verified, CASE_DONE reports32400s, the exact source-bound GPU gate was admitted, every scheduled output was present/finite/on native coordinates, and strict export collection admitted2/rejected0. Scheduler status must not be described as successful; nor does its teardown discrepancy alone invalidate independently verified scientific output.
