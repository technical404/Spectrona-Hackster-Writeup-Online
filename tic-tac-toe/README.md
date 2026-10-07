# CTF Report — `tic_tac_toe.exe` (Impossible Tic-Tac-Toe)

**Category:** Reverse Engineering (PyInstaller / Python bytecode)
**Author:** Priyank Rastogi
**Date:** 2026-10-05
**Flag:** `HKSTR{y0u_sh0u1d_n0t_533_th15}`

---

## TL;DR

`tic_tac_toe.exe` is a PyInstaller-packaged Tkinter game with an **unbeatable
minimax AI** — you can never win, hence "Impossible". The flag is a **plaintext
module-level constant** inside the bundled `game.pyc`, shown only on a win.
Unpacking the PyInstaller archive and decompiling the `.pyc` recovers it directly.

---

## 1. Artifact

| Property | Value |
|---|---|
| Path | `tic_tac_toe.exe` (same folder as this report) |
| Size | `9,470,324` bytes |
| Type | PE32+ GUI, PyInstaller onefile (Python 3.10, Tkinter) |
| MD5 | `1c16ce67791265ea3e0eaf52c0ea773a` |

---

## 2. Unpacking (PyInstaller)

```bash
python3 pyinstxtractor.py tic_tac_toe.exe
# -> tic_tac_toe.exe_extracted/
#    game.pyc            <- the application script
#    python310.dll, _tk_data/, _tcl_data/, ...
```

The entry script is `game.pyc` (Python 3.10 bytecode).

## 3. Decompiling

```bash
pycdc game.pyc            # Decompyle++ (built from source)
```

Decompiled output (excerpt):

```python
import tkinter as tk
from tkinter import messagebox

FLAG = 'HKSTR{y0u_sh0u1d_n0t_533_th15}'

class TicTacToe:
    def __init__(self, root):
        ...
```

The flag is shown via:

```python
messagebox.showinfo('Winner', f"You won!\n{FLAG}")
```

Because the AI is a full **minimax** search, a real 3×3 game is a guaranteed
draw-or-loss for the player — so the branch is effectively unreachable. The
author left the string in the clear (and even named it "you should not see
this").

`strings` on `game.pyc` also confirms the constant:

```bash
strings -a game.pyc | grep HKSTR
# HKSTR{y0u_sh0u1d_n0t_533_th15}
```

---

## 4. Flag

```
HKSTR{y0u_sh0u1d_n0t_533_th15}
```

("you should not see this")

---

## 5. Takeaways

* PyInstaller onefile bundles are trivially unpacked (`pyinstxtractor`) and the
  entry `.pyc` decompiled (`pycdc`/`uncompyle6`) — never ship secrets in Python
  bytecode.
* A "you can't win" mechanic often means the winning branch holds a static
  secret rather than a runtime challenge.

---

## Tools used

`pyinstxtractor`, `pycdc` (Decompyle++), `strings`.

*Write-up by **Priyank Rastogi**.*