# CTF Report — `vault_airship.pyc` (Chained SHA-256 Vault)

**Category:** Reverse Engineering (Python bytecode)
**Author:** Priyank Rastogi
**Date:** 2026-10-05
**Flag:** `HKSTR{PY77H0N_4553M81Y_15_5Ur3_r34D4813_7H4N_N0rM41_4553M81Y}`

---

## TL;DR

`vault_airship.pyc` is an Among Us–themed **4-stage vault** in CPython 3.10
bytecode. Each stage checks
`sha256(password + running_fragments) == stored_hash`, so the flag is revealed
once all four stage passwords are supplied in order. The passwords are simple
Among-Us trivia, and the flag fragments are XOR-obfuscated with a 4-byte key.

---

## 1. Artifact

| Property | Value |
|---|---|
| Path | `vault_airship.pyc` (same folder as this report) |
| Type | CPython 3.10 bytecode |
| Size | `4,628` bytes |

Decompiled cleanly with the bundled `pycdc` (Decompyle++).

---

## 2. How it works

The module XOR-obfuscates its data with a per-array key:

```python
_K = [19, 65, 115, 105]        # ASCII: \x13 'A' 's' 'i'  ("Asi" — Among-Us-ish)
_F[i] ^ _K[i]  ->  4 flag fragments
_H[i] ^ _K[i]  ->  4 SHA-256 targets
```

Each stage checks a **chained hash**:

```python
sha256(password + "".join(previous_fragments)) == _H[stage]
```

The flag fragments recovered by XOR:

```
1. HKSTR{PY77H0N_
2. 4553M81Y_15_
3. 5Ur3_r34D4813_
4. 7H4N_N0rM41_4553M81Y}
```

### Passwords (verified by hash match)

| Stage | Hint | Password |
|---|---|---|
| 1 | Black's pet snake | `pie` |
| 2 | The map | `airship` |
| 3 | Crewmate color | `black` |
| 4 | Black's secret role | `impostor` |

---

## 3. Solving

```bash
printf 'pie\nairship\nblack\nimpostor\n' | python3 vault_airship.pyc
# -> FLAG: HKSTR{PY77H0N_4553M81Y_15_5Ur3_r34D4813_7H4N_N0rM41_4553M81Y}
```

Feeding the four words in order makes the running `parts` chain match each stage
hash, so all four verify and the flag is assembled.

> **Amusing bug in the original:** the decompiled `main` prints `hints[0]` for
> every stage (always the snake hint) instead of `hints[i]` — a real flaw in the
> author's script that leaks the stage-1 hint repeatedly.

---

## 4. Flag

```
HKSTR{PY77H0N_4553M81Y_15_5Ur3_r34D4813_7H4N_N0rM41_4553M81Y}
```

("PYTHON ASSEMBLY IS SURE READABLE THAN NORMAL ASSEMBLY")

---

## 5. Takeaways

* Chained hashing binds each stage to the accumulated state — you still just need
  the right inputs in order; the chain doesn't add cryptographic strength if the
  inputs are guessable.
* XOR with a repeating short key is not protection: recover the key from known
  plaintext (the `HKSTR{` prefix) or straight from the bytecode constants.

---

## Tools used

`pycdc` (Decompyle++), Python 3 stdlib (`hashlib`).

*Write-up by **Priyank Rastogi**.*