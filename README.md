# Open Abbrev

[한국어 안내서 / Korean README](korean)

**Open Abbrev** is a Windows Open-source abbreviation tool that lets you enter words and phrases with short key combinations. It supports **sequences** (typing keys in order) and **chords** (pressing keys nearly together). You can edit the abbreviation lists for your keyboard layout.

The English abbreviation dictionaries were compiled with reference to word frequency data from the **Corpus of Contemporary American English (COCA)**, while the Korean dictionaries were compiled with reference to word frequency statistics published by the **National Institute of Korean Language**.

This project is currently in the **Alpha** stage as an AutoHotkey prototype. 
(The AutoHotkey code was created with the help of AI.)

---

# I. User Guide

## 1. Installation and startup

You need Windows and [AutoHotkey v2](https://www.autohotkey.com/).

1. Install AutoHotkey v2.
2. Download and extract Open Abbrev.
3. Open `open-abbrev.ahk` in a text editor. Find `DictionaryDir` near the top and select your abbreviation folder.
(Keep `open-abbrev.ahk` and the language folders (such as `english`) under the same parent folder.)
4. Save the file and run `open-abbrev.ahk`.

For the **Windows IME with English QWERTY**, use:

```ahk
global DictionaryDir := A_ScriptDir "\english\windows-ime\qwerty"
```

For **Nalgaeset IME with Colemak**, use:

```ahk
global DictionaryDir := A_ScriptDir "\english\nalgaeset-ime\colemak"
```

If a folder does not have an abbreviation list yet, copy one from another folder and edit it.

　
- **Antivirus False Positive Notice:** As this program intercepts, rearranges and re-enters keyboard input, it may trigger false positives in the behaviour-based detection mechanisms of some antivirus programs; It is recommended that you add this script to the exceptions list of your antivirus program.

## 2. Entering abbreviations

| Method | How it works | Example |
|---|---|---|
| **Sequence** | Type the keys in order, then press Space or another ending key. | Type `func` then Space → `function` |
| **Chord** | Press the listed keys nearly together; their order does not matter. | Press the keys in `the` together |

Sequences expand **when you press an ending key**, not immediately when the letters appear. Chords group keys entered within **0.040 seconds** by default. The actual result depends on your abbreviation list.

## 3. Turning abbreviations on and off

Abbreviations start **ON** when the program runs. Press **Scroll Lock or F9** to toggle them.

| State | Behavior | Scroll Lock indicator |
|---|---|---|
| ON | Abbreviations work. | On |
| OFF | Keys are entered normally. | Off |

A message, `Open Abbrev = On` or `Open Abbrev = Off`, appears for about 0.8 seconds after each change. Temporarily turn the tool OFF when you need to type an abbreviation literally. F9 also works on keyboards without a Scroll Lock indicator.

## 4. Adding and editing abbreviations

Each abbreviation folder contains two files that you can open in **Excel or another spreadsheet editor**:

- `sequence.csv`: sequences
- `chord.csv`: chords

In both files, the left column (`keys`) contains the **keys to press**, and the right column (`output`) contains **the resulting text**.

**Sequence example (`sequence.csv`)**

```csv
keys,output
func,function
drn,during
```

On Excel, enter it as:
| keys | output |
| func | function |
| drn  | during   |

**Chord example (`chord.csv`)**

```csv
keys,output
the,the
be,be
```

On Excel, enter it as:
| keys | output |
| the  | the    |
| be   | be     |


To add an abbreviation, add a row at the bottom. **If an abbreviation is listed more than once, the last row wins.** For chords, key order does not matter: `abc` and `cba` are the same chord.

Supported abbreviation keys are lowercase `a` through `z`, plus `;`, `,`, and `.`. Sequences are case-sensitive.

**Note:** The CSV format supports quoted commas; `,` is entered as `","`. But **does not** support line breaks inside fields. See the developer section for format limitations.

## 5. Choosing a list for your keyboard

**The same keyboard layout may need different abbreviation lists for Windows IME and Nalgaeset IME.** Choose the folder that matches both your input method and layout.

For example, with Nalgaeset Colemak, the program may receive the QWERTY-position keys `fhk`(When 'the' of Colmak is typed, it is interpreted as `fhk` in QWERTY position) when you type `the`. In that case, the dictionary should also use `fhk`. If you copied a list from another layout, test it and adjust the entries as needed.

## 6. Troubleshooting

- If nothing expands, check that the tool is ON and that `DictionaryDir` points to the correct folder.
- If the wrong text appears, check the corresponding dictionary entry. If the same abbreviation appears more than once, check the **last occurrence**.
- Other keyboard utilities may interfere with the tool, especially layouts with their own chording features.
- Use Scroll Lock or F9 to disable abbreviations temporarily.

---

# II. Developer Documentation

## 1. Design principles

> One shared engine + CSV abbreviation dictionaries per IME, language, and keyboard layout

The engine handles key collection, dictionary lookup, expansion, and ON/OFF state. It does not contain per-layout conversion tables; dictionary authors handle IME-specific key mappings.

In the target setup, Windows IME applies layout conversion before AutoHotkey processes input, whereas Nalgaeset IME may expose QWERTY-position characters to AutoHotkey first. Thus, `the` may be stored as `the,the` for Windows IME and `fhk,fhk` for Nalgaeset Colemak; Verify the behavior in the actual input environment.

## 2. Directory layout and dictionary selection

```text
open-abbrev/
├── open-abbrev.ahk
├── README.md                 # English
├── docs/
│   └── README.ko.md          # Korean
├── english/
│   ├── windows-ime/
│   │   ├── qwerty/
│   │   ├── dvorak/
│   │   └── colemak/
│   └── nalgaeset-ime/
│       ├── qwerty/
│       ├── dvorak/
│       └── colemak/
└── korean/
    ├── windows-ime/
    └── nalgaeset-ime/
```

This is the intended structure, not a claim that every dictionary is already bundled. Each dictionary folder contains `sequence.csv` and `chord.csv`, with an optional `endchars.csv`. Select a folder using the variance `DictionaryDir`.

## 3. Sequence and chord dictionary format

| Property | Specification |
|---|---|
| Encoding | UTF-8 |
| Files | `sequence.csv`, `chord.csv` |
| Header | `keys,output` |
| Comments | Ignore lines beginning with `#` after trimming whitespace |
| Empty lines | Ignored |
| Separator | **comma** |
| `keys` | `a-z`, `;`, `,`, `.` |
| `output` | Cannot be empty or contain line breaks; commas and double quotes supported via CSV quoting |
| Inline comments | Not supported |
| Standard CSV quoted fields | Supported (except embedded line breaks) |

For example, `",a",example` means `keys` is `,a` and `output` is `example`. Double a literal quote inside a quoted field. Standard CSV quoted fields are supported, except embedded line breaks.

**Duplicate policy: Last Wins.** For sequences, the last occurrence of identical `keys` takes precedence. For chords, keys are normalized using `SortKeys(keys)`; the last row with the same signature wins. Duplicates do not abort startup.

## 4. Ending characters (`endchars.csv`)

Without this file, the shared default ending-character set is used. When present, the file has two columns, `operation,key`, and adds or removes characters from the default set.

**Effective ending characters = (defaults − remove) ∪ add**

Nalgaeset Colemak example:

```csv
operation,key
add,P
add,p
remove,;
remove,:
```

Nalgaeset Dvorak example:

```csv
operation,key
add,Q
add,q
add,W
add,w
add,E
add,e
add,Z
add,z
remove,;
remove,:
remove,'
remove,double-quote
remove,.
remove,comma
```

`comma` means `,`, and `double-quote` means `"`. These reserved names avoid separator and quoting problems when editing in Excel. Unlike the sequence/chord dictionaries, `endchars.csv` is a conventional two-column CSV. The common ending-character set includes Space, Enter, Tab, and supported punctuation; consult the engine for the exact defaults.

## 5. Sequence handling

Sequences use AutoHotkey v2's dynamic `Hotstring()`, with case sensitivity and `SendEvent` output:

```ahk
LoadSequences(path) {
    global SequenceNames
    for entry in ReadDictionary(path) {
        SequenceNames[entry.keys] := true
        Hotstring(":CRSE:" entry.keys, entry.output)
    }
}
```

Registering the same key again updates its replacement, so the last occurrence wins. Users can temporarily turn the tool OFF to enter a conflicting identifier literally.

## 6. Chord handling

1. Collect supported character-key events while enabled.
2. Group events in a default 40ms window from the first key.
3. Sort collected keys into an order-independent signature and look it up in `chord.csv`.
4. Send the replacement via `SendEvent` on a match; otherwise replay the original keys.

This is a short event-window approach, not hardware-level detection of perfectly simultaneous keydown events. Duplicate signatures use the last row.

## 7. Output and state

Chord expansion uses `SendEvent "{Raw}" Chords[signature]`. `SendText` is avoided because of issues observed during high-speed typing. Input-level settings that allow replayed events and hotstrings to cooperate require runtime testing on Windows.

Startup state is ON; F9 and Scroll Lock toggle it. When OFF, `Suspend` bypasses ordinary abbreviation handling, while `#SuspendExempt` keeps both toggle keys available. Toggling clears pending chord buffers and timers, synchronizes the Scroll Lock indicator, and shows a tooltip for 800ms.

## 8. Implementation and validation

- Verify sequence case sensitivity, Last Wins behavior, and Shift handling for chords on the target system.
- Verify `endchars.csv` add/remove behavior under Nalgaeset Colemak and Dvorak.
- Verify encoding and delimiters after editing CSV files in Excel.
- Test interactions with other AutoHotkey scripts, IME-provided chording, language switching, and key remappers.

**This document describes intended behavior and usage; it does not claim comprehensive runtime verification on Windows or Nalgaeset IME.**

## 9. Scope

The goal is a small shared engine. A complete CSV parser, automatic IME detection, IME-specific conversion tables, and separate engines for each layout are out of scope.
