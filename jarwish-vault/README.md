# CTF Report — `jarwish_vault.h5` (Stego in a Keras HDF5 Model)

**Category:** Steganography / ML Forensics
**Author:** Priyank Rastogi
**Date:** 2026-10-05
**Flag:** `HKSTR{THE_SECRET_IS_KNOWN}`

---

## TL;DR

`jarwish_vault.h5` is an HDF5 (Keras) model. The hidden payload is planted in the
**dense layer's bias tensor**: a contiguous prefix of **19 anomalously
2-decimal-rounded values** in `0.98–1.27`. XOR-ing the recovered bytes with a key
brute-forced over all byte values yields exactly one clean message —
`THE_SECRET_IS_KNOWN` — which is the flag content.

---

## 1. Artifact

| Property | Value |
|---|---|
| Path | `jarwish_vault.h5` (same folder as this report) |
| Type | HDF5 / Keras model |
| Size | `2,760,392` bytes |
| Model name | `jarwish` |
| Tooling | `h5py`, Python |

---

## 2. Locating the payload

Inspect the tensors:

```python
import h5py, numpy as np
f = h5py.File('jarwish_vault.h5','r')
# walk groups: jarwish_conv2d_*, jarwish_dense_layer/{kernel,bias}, ...
bias = f['jarwish_dense_layer/bias'][:]
```

The bias tensor's **first 19 entries** are conspicuously rounded to 2 decimals
and clustered in `0.98–1.27` — clearly deliberate, while the rest are normal
floats. Those 19 values (×100, rounded) are the payload bytes:

```
101,121,116,110,98,116,114,99,116,101,110,120,98,110,122,127,126,102,127
```

---

## 3. Decoding

Brute-force a single-byte XOR key across all 256 possibilities and keep the
output that is printable text:

```python
vals = [101,121,116,110,98,116,114,99,116,101,110,120,98,110,122,127,126,102,127]
for k in range(256):
    s = ''.join(chr(v ^ k) for v in vals)
    if s.isprintable():
        print(k, s)
```

Only **key 49** produces clean text:

```
49 THE_SECRET_IS_KNOWN
```

(The distinctive separators — underscores, a full sentence — confirm 49 is the
correct key, versus the garbage produced by other keys.)

---

## 4. Flag

```
HKSTR{THE_SECRET_IS_KNOWN}
```

> The decoded plaintext is UPPERCASE with underscores; the natural flag is
> `HKSTR{THE_SECRET_IS_KNOWN}`. (Possible casing alternates:
> `HKSTR{the_secret_is_known}` / `HKSTR{Th3_S3cr3t_1s_Kn0wn}`.)

---

## 5. Takeaways

* ML model files are just structured containers — inspect **every** tensor, not
  only the "interesting" ones. Anomalous precision/range is the tell.
* The model **name** (`jarwish`) and repeated layer prefixes are theme noise; the
  payload was a contiguous prefix in a single array.
* A single-byte XOR brute-force is a 2-line solve once the byte stream is found.

---

## Tools used

`h5py`, `numpy`, Python (XOR brute-force).

*Write-up by **Priyank Rastogi**.*