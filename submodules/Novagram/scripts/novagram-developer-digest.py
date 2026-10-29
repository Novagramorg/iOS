#!/usr/bin/env python3
"""
novagram-developer-digest.py — the digest for a Developer-section login (Novagram iOS).

Settings: hold the version line for 20 s, then log in. Only a PBKDF2 digest of
"<login>|<password>" ships in the app, one per role, in `credentials` in
submodules/Novagram/Messenger/Sources/NovagramAdsAdminAuth.swift. To add a login
or change a password, run this and put the printed digest there next to its role.

    python3 submodules/Novagram/scripts/novagram-developer-digest.py director

The password is asked without echo (from a terminal) or read from the first line
of stdin, so it never lands in shell history. The login is trimmed and lowercased
like the app does; the password is used exactly as typed.
"""

import getpass
import hashlib
import sys

# Must match NovagramAdsAdminAuth.saltHex and .rounds.
SALT_HEX = "6ced8c7f8279470c768f8739196a445b"
ROUNDS = 600_000


def digest(login: str, password: str) -> str:
    secret = f"{login.strip().lower()}|{password}".encode("utf-8")
    return hashlib.pbkdf2_hmac("sha256", secret, bytes.fromhex(SALT_HEX), ROUNDS, dklen=32).hex()


def main() -> int:
    if len(sys.argv) != 2 or not sys.argv[1].strip():
        print("usage: novagram-developer-digest.py <login>", file=sys.stderr)
        return 2
    if sys.stdin.isatty():
        password = getpass.getpass("Password: ")
        if password != getpass.getpass("Again: "):
            print("The passwords do not match.", file=sys.stderr)
            return 1
    else:
        password = sys.stdin.readline().rstrip("\n")
    if not password:
        print("Empty password.", file=sys.stderr)
        return 1
    print(digest(sys.argv[1], password))
    return 0


if __name__ == "__main__":
    sys.exit(main())
