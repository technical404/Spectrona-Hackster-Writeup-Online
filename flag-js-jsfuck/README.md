# CTF Report — `flag.js` (JSFuck)

**Category:** Crypto / Web (JavaScript obfuscation)
**Author:** Priyank Rastogi
**Date:** 2026-10-05
**Flag:** `HKSTR{J5_F*UK_W45_N0T_TH4tt_B4D}`

---

## TL;DR

`flag.js` is standard, self-contained **JSFuck** — code written using only
`[]()!+` characters. Evaluating the file returns the flag directly. It is
challenge #1 of a two-part JSFuck pair (`flag.js` / `flag2.js`).

---

## 1. Artifact

| Property | Value |
|---|---|
| Path | `flag.js` (same folder as this report) |
| Size | `5,667` bytes |
| Type | JavaScript (JSFuck) |
| Self-contained | Yes |

---

## 2. What is JSFuck

JSFuck encodes any JavaScript using only six characters — `[`, `]`, `(`, `)`,
`!`, `+` — by abusing type coercion:

* `![]` → `false`, `!![]` → `true`
* `+[]` → `0`, `(![]+[])[+[]]` → `"f"` (first char of `"false"`)
* Strings built from `"false"`, `"true"`, `"undefined"`, `"NaN"`, etc.
* `Function(...)` constructed dynamically and invoked.

---

## 3. Solving

The file is an expression; evaluate it and print the result:

```bash
node -e "console.log(eval(require('fs').readFileSync('flag.js','utf8')))"
```

or in a browser console / any JS engine:

```js
eval(<contents of flag.js>)
```

Output:

```
HKSTR{J5_F*UK_W45_N0T_TH4tt_B4D}
```

Reads as **"JS F\*CK WAS NOT THAT BAD"** (the `F*UK` masks "FUCK").

---

## 4. Flag

```
HKSTR{J5_F*UK_W45_N0T_TH4tt_B4D}
```

---

## 5. Takeaways

* JSFuck is fully reversible: never treat "only six characters" as encryption.
  A JS engine (or a deobfuscator) decodes it trivially.
* Evaluate as an **expression** and print the returned value — many JSFuck
  payloads return the secret rather than printing it.

---

## Related

* `flag2.js` — the second JSFuck challenge (see `../flag2-js-jsfuck/`).

---

## Tools used

`node`, browser console.

*Write-up by **Priyank Rastogi**.*