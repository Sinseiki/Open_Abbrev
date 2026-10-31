#Requires AutoHotkey v2.0
#SingleInstance Force

; Shared engine: choose a dictionary; endchars.csv is loaded from that folder.
global DictionaryDir := A_ScriptDir "\english\windows-ime\qwerty"

global ChordTime := 40
global SupportedKeys := "abcdefghijklmnopqrstuvwxyz;,."
global Chords := Map()
global Keys := []
global SequenceNames := Map()

; Optional add/remove differences relative to the common ending characters.
; If absent, use the common defaults.
LoadEndChars(DictionaryDir "\endchars.csv")
LoadSequences(DictionaryDir "\sequence.csv")
LoadChords(DictionaryDir "\chord.csv")

; Register each input key ONCE. These dynamically created hotkeys are
; subject to Suspend. I1 prevents our SendLevel(1) replay from looping.
HotIf IsUnshifted
for key in StrSplit(SupportedKeys)
    Hotkey("$" key, OnKey.Bind(key), "I1")
HotIf

; Start enabled.
SetScrollLockState "On"

; These toggle hotkeys stay active while Suspended.
#SuspendExempt
$ScrollLock::ToggleAbbrev()
$F9::ToggleAbbrev()
#SuspendExempt False

; Replay pending lowercase input before the modifier changes a following key.
~*LShift::Flush()
~*RShift::Flush()
~*CapsLock::Flush()

ToggleAbbrev() {
    global Keys

    if A_IsSuspended {
        Keys := []
        Hotstring "Reset"
        Suspend 0
    } else {
        SetTimer Flush, 0
        pending := Keys
        Keys := []
        Suspend 1
        Hotstring "Reset"

        if pending.Length
            ReplayKeys(pending)
    }

    enabled := !A_IsSuspended
    SetScrollLockState(enabled ? "On" : "Off")

    ToolTip("Open Abbrev = " (enabled ? "On" : "Off"))
    SetTimer HideTip, -800
}

HideTip() {
    ToolTip()
}

; The chord hook must never consume uppercase letters or their modifiers.
; With this condition false, Windows/IME receives the real key event.
IsUnshifted(*) {
    return !GetKeyState("Shift", "P") && !GetKeyState("CapsLock", "T")
}

LoadEndChars(path) {
    ; The two-column CSV is editable in Excel. One key per row.
    defaults := "-()[]{}:;'" Chr(34) "/" Chr(92) ",.?!@#$%^&*+=_``~<>|`n`t "
    if !FileExist(path) {
        Hotstring("EndChars", defaults)
        return
    }

    additions := ""
    removals := ""
    for line in StrSplit(StrReplace(FileRead(path, "UTF-8"), "`r"), "`n") {
        line := Trim(line, " `t")
        if (line = "" || SubStr(line, 1, 1) = "#" || line = "operation,key")
            continue

        ; Exactly two columns: operation and key. "comma" is the comma key;
        ; "double-quote" avoids Excel's CSV quoting ambiguity.
        fields := StrSplit(line, ",")
        if (fields.Length != 2)
            throw Error("Invalid endchars.csv row: " line)
        operation := Trim(fields[1], " `t")
        key := Trim(fields[2], " `t")
        if (key = "comma")
            key := ","
        else if (key = "double-quote")
            key := Chr(34)
        if (StrLen(key) != 1 || (operation != "add" && operation != "remove"))
            throw Error("Invalid endchars.csv entry: " line)
        if (operation = "add")
            additions .= key
        else
            removals .= key
    }

    endings := defaults
    for char in StrSplit(removals)
        endings := StrReplace(endings, char)
    for char in StrSplit(additions)
        if !InStr(endings, char, true)
            endings .= char
    Hotstring("EndChars", endings)
}

LoadSequences(path) {
    global SequenceNames
    for entry in ReadDictionary(path) {
        SequenceNames[entry.keys] := true
        Hotstring(":CRSE:" entry.keys, entry.output)
    }
}

LoadChords(path) {
    global Chords
    for entry in ReadDictionary(path)
        Chords[SortKeys(entry.keys)] := entry.output
}

ReadDictionary(path) {
    global SupportedKeys
    if !FileExist(path)
        throw Error("Dictionary file not found: " path)
    entries := []
    content := FileRead(path, "UTF-8")
    for line in StrSplit(content, "`n", "`r") {
        if (Trim(line, " `t") = "" || SubStr(LTrim(line, " `t"), 1, 1) = "#")
            continue

        fields := ParseCsvRow(line)
        if (fields.Length != 2)
            throw Error("Expected two CSV fields: " line)
        if (fields[1] = "keys" && fields[2] = "output")
            continue

        keys := fields[1]
        output := fields[2]
        if (keys = "" || output = "")
            throw Error("Empty CSV field: " line)
        for char in StrSplit(keys) {
            if !InStr(SupportedKeys, char, true)
                throw Error("Unsupported key '" char "' in: " line)
        }
        entries.Push({keys: keys, output: output})
    }
    return entries
}

; Standard CSV quoting for a single record: quoted commas and doubled quotes.
; Multiline fields are intentionally unsupported.
ParseCsvRow(line) {
    fields := []
    field := ""
    quoted := false
    closed := false
    atStart := true
    quote := Chr(34)
    i := 1
    while (i <= StrLen(line)) {
        char := SubStr(line, i, 1)
        if quoted {
            if (char = quote) {
                if (SubStr(line, i + 1, 1) = quote) {
                    field .= quote
                    i += 1
                } else {
                    quoted := false
                    closed := true
                }
            } else {
                field .= char
            }
        } else if (char = ",") {
            fields.Push(field)
            field := ""
            atStart := true
            closed := false
        } else if (atStart && char = quote) {
            quoted := true
            atStart := false
        } else if (closed || char = quote) {
            throw Error("Invalid CSV quoting: " line)
        } else {
            field .= char
            atStart := false
        }
        i += 1
    }
    if quoted
        throw Error("Unclosed CSV quote: " line)
    fields.Push(field)
    return fields
}

SortKeys(keys) {
    global SupportedKeys
    counts := Map()
    for key in StrSplit(keys)
        counts[key] := counts.Get(key, 0) + 1
    result := ""
    for key in StrSplit(SupportedKeys) {
        Loop counts.Get(key, 0)
            result .= key
    }
    return result
}

OnKey(key, *) {
    global Keys, ChordTime
    Keys.Push(key)
    if Keys.Length = 1
        SetTimer Flush, -ChordTime
}

Flush() {
    global Keys, Chords
    if A_IsSuspended || !Keys.Length
        return

    captured := Keys
    Keys := []
    typed := ""
    for key in captured
        typed .= key

    if captured.Length > 1 {
        signature := SortKeys(typed)
        if Chords.Has(signature) {
            ; Send expansion through SendEvent; Raw prevents AHK Send syntax parsing.
            SendEvent "{Raw}" Chords[signature]
            return
        }
    }

    ; Non-chord input MUST be sent as key events to go through the IME.
    ReplayKeys(captured)
}

ReplayKeys(keys) {
    ; Hotstring input level 0 can see these synthetic key events (level 1),
    ; while our input hotkeys at I1 ignore them (no feedback loop).
    previousLevel := SendLevel(1)
    for key in keys
        SendEvent "{" key "}"
    SendLevel previousLevel
}
