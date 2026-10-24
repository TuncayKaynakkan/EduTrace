"""Socket.IO auth check: plays the "other program on this PC" against a running engine.

Run it in a normal (non-admin) terminal while edutrace_ultimate.py is running:

    python tools/yetkisiz_istemci.py            # no token  -> must be refused
    python tools/yetkisiz_istemci.py --yanlis   # bad token -> must be refused
    python tools/yetkisiz_istemci.py --dogru    # real token from auth.token -> must connect

It only connects; it never sends a command to the engine.
"""

from __future__ import annotations

import os
import sys

import socketio

URL = "http://127.0.0.1:5000"


def token_oku() -> str:
    kok = os.getenv("PROGRAMDATA") or os.path.expanduser("~")
    with open(os.path.join(kok, "EduTrace", "auth.token"), encoding="utf-8") as f:
        return f.read().strip()


def main() -> int:
    mod = sys.argv[1] if len(sys.argv) > 1 else "--tokensiz"
    auth = {"--tokensiz": None, "--yanlis": {"token": "tahmin-edilen-token"}}.get(mod)
    if mod == "--dogru":
        auth = {"token": token_oku()}

    istemci = socketio.Client(reconnection=False)
    try:
        istemci.connect(URL, auth=auth, transports=["polling"], wait_timeout=5)
    except socketio.exceptions.ConnectionError as exc:
        print(f"[{mod}] REDDEDILDI: {exc}")
        return 0 if mod != "--dogru" else 1
    print(f"[{mod}] BAGLANDI")
    istemci.disconnect()
    return 0 if mod == "--dogru" else 1


if __name__ == "__main__":
    sys.exit(main())
