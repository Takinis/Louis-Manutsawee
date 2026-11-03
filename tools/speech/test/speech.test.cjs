const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const { parseSpeech, analyze, rewriteSpeech, Catalog, scan, prepare, write, get, validateText, audit } = require("../lib.cjs");

function fixture() {
    // Keep temporary fixtures for inspection; never recursively delete directories.
    const directory = fs.mkdtempSync(path.join(os.tmpdir(), "dst-speech-test-"));
    const root = path.join(directory, "mod");
    const source = path.join(directory, "scripts");
    function save(relative, content) {
        const file = path.join(directory, relative);
        fs.mkdirSync(path.dirname(file), { recursive: true });
        fs.writeFileSync(file, content);
    }
    save("scripts/speech_wilson.lua", `return {
    ANNOUNCE_NEW = "Hello, %s!",
    DESCRIBE = {
        BAT = { GENERIC = "A bat.", ACID = "Acid!" },
        NEW = "A new thing.",
        OPTIONAL = { SPECIAL = "only_used_by_wx78" },
    },
    POOL = { "One.", "Two." },
}`);
    const speech = `-- Keep this comment.
return {
    DESCRIBE = {
        BAT = "Old bat.",
        NEW = "",
        MOD_ITEM = "Keep custom speech.",
    },
    POOL = {
        "My first line.",
        "My second line.",
        "My extra line.",
    },
}
`;
    save("mod/strings/manutsawee.lua", speech);
    save("mod/strings/kiritzuka.lua", speech);
    const context = "STRINGS.CHARACTERS.MANUTSAWEE.DESCRIBE.BAT";
    save("mod/scripts/languages/chinese_s.po", `msgid ""
msgstr ""
"Content-Type: text/plain; charset=UTF-8\\n"

# Translator note.
#. ${context}
msgctxt "${context}"
msgid "Old bat."
msgstr "Existing translation."
`);
    save("mod/scripts/languages/strings.pot", `msgctxt "${context}"
msgid "Old bat."
msgstr ""
`);
    return { root, source, directory, save };
}

function complete(report) {
    for (const character of report.characters) {
        for (const entry of character.entries) {
            if (entry.reason !== "catalog") entry.text = "Custom: " + entry.reference;
            if (Object.hasOwn(entry, "translation")) entry.translation = "Translated: " + entry.text;
        }
    }
    return report;
}

test("Lua parsing preserves Unicode and escapes without executing code", () => {
    const parsed = parseSpeech('return { LINE = "中文\\n\\\\n\\\"quote\\\"" }');
    assert.equal(parsed.value.LINE, '中文\n\\n"quote"');
    assert.throws(() => parseSpeech('return os.execute("echo unsafe")'));
    assert.throws(() => parseSpeech('local x = {}; return x'));
    assert.throws(() => parseSpeech('return { A = "first", A = "second" }'), /Duplicate/);
    assert.throws(() => parseSpeech('return { [1] = "first", "second" }'), /Duplicate/);
});

test("Analysis filters private placeholders, migrates generic states, and retains pools", () => {
    const base = {
        ITEM: { GENERIC: "item", ACTIVE: "active" },
        POOL: { 1: "one", 2: "two" },
        CUSTOM_POOL: "a single native line",
        SKIP: { ONLY: "only_used_by_wendy" },
        EMPTY: "fill",
    };
    const speech = { ITEM: "old item", POOL: { 1: "first" }, CUSTOM_POOL: { 1: "a", 2: "b" }, EMPTY: "  " };
    const result = analyze(base, speech);
    assert.deepEqual(result.migrations, ["ITEM"]);
    assert.equal(result.normalized.ITEM.GENERIC, "old item");
    assert.deepEqual(result.missing.map(entry => entry.path), ["EMPTY", "ITEM.ACTIVE", "POOL.2"]);
    assert.deepEqual(result.conflicts, []);
    assert.equal(speech.ITEM, "old item");
    assert.equal(analyze({ A: { 1: "line" } }, { A: "old" }).conflicts.length, 1);
    assert.equal(analyze({ A: "line" }, { A: { 2: "hole" } }).conflicts.length, 1);
});

test("AST rewrite keeps comments, old text, numeric indices, and trailing comma syntax", () => {
    const source = '-- header\nreturn {\n    -- Keep me.\n    A = "old",\n    POOL = {\n        "first"\n    }\n}\n';
    const parsed = parseSpeech(source);
    const desired = structuredClone(parsed.value);
    desired.B = "new";
    desired.POOL[2] = "second";
    const updated = rewriteSpeech(parsed, desired);
    assert(updated.includes('-- Keep me.\n    A = "old",'));
    assert.equal(parseSpeech(updated).value.POOL[1], "first");
    assert.equal(parseSpeech(updated).value.POOL[2], "second");
    assert.equal(rewriteSpeech(parseSpeech(updated), desired), updated);
});

test("AST rewrite handles compact tables, CRLF, semicolons and explicit numeric keys", () => {
    for (const source of ['return { A = "old" }', 'return {\r\n    A = "old";\r\n}\r\n']) {
        const updated = rewriteSpeech(parseSpeech(source), { A: "old", B: { 10: "ten", 2: "two" } });
        assert.deepEqual(parseSpeech(updated).value, { A: "old", B: { 10: "ten", 2: "two" } });
        if (source.includes("\r\n")) assert(!/(?<!\r)\n/.test(updated));
    }
});

test("PO migrations preserve comments and multiline escaped values", () => {
    const source = '# Note\nmsgctxt "OLD"\nmsgid ""\n"First\\\\n"\n"Second"\nmsgstr "旧台词\\n下一行"\n';
    const catalog = new Catalog(source);
    assert.equal(catalog.entries.get("OLD").msgid, "First\\nSecond");
    catalog.migrate("OLD", "OLD.GENERIC");
    catalog.set("NEW", 'New "quote".', "新台词");
    const roundtrip = new Catalog(catalog.text());
    assert(!roundtrip.entries.has("OLD"));
    assert.equal(roundtrip.entries.get("OLD.GENERIC").msgstr[0], "旧台词\n下一行");
    assert.equal(roundtrip.entries.get("NEW").msgid, 'New "quote".');
    assert(catalog.text().includes("# Note"));
    assert.throws(() => new Catalog(source + "\n" + source), /Duplicate/);
    assert.throws(() => roundtrip.migrate("NEW", "OLD.GENERIC"), /collision/);
});

test("Formatting tokens retain printf order and named placeholders", () => {
    validateText("{owner}: %s has {weight}", "%s {weight} {owner}", "ok");
    assert.throws(() => validateText("Hello!", "Hello %s!", "missing"), /placeholders/);
    assert.throws(() => validateText("%d %s", "%s %d", "order"), /placeholders/);
    assert.throws(() => validateText("only_used_by_wx78", "line", "private"), /Invalid/);
    assert.throws(() => validateText("bad\u0000", "line", "control"), /Control/);
});

test("Scan, preview, import, backups, and a fresh no-op scan work end to end", () => {
    const { root, source } = fixture();
    const report = scan({ root, source });
    assert.equal(report.characters.length, 2);
    assert.deepEqual(report.characters[0].migrations, ["DESCRIBE.BAT"]);
    const before = fs.readFileSync(path.join(root, "strings/manutsawee.lua"), "utf8");
    const prepared = prepare(root, complete(report));
    assert.equal(fs.readFileSync(path.join(root, "strings/manutsawee.lua"), "utf8"), before);
    assert(!fs.existsSync(path.join(root, "tools/speech/backups")));
    const backup = write(root, report, prepared);
    assert.equal(fs.readFileSync(path.join(backup, "strings/manutsawee.lua"), "utf8"), before);
    const result = parseSpeech(fs.readFileSync(path.join(root, "strings/manutsawee.lua"), "utf8")).value;
    assert.equal(result.DESCRIBE.BAT.GENERIC, "Old bat.");
    assert.equal(result.DESCRIBE.MOD_ITEM, "Keep custom speech.");
    assert.equal(result.POOL[3], "My extra line.");
    const locale = new Catalog(fs.readFileSync(path.join(root, "scripts/languages/chinese_s.po"), "utf8"));
    assert.equal(locale.entries.get("STRINGS.CHARACTERS.MANUTSAWEE.DESCRIBE.BAT.GENERIC").msgstr[0], "Existing translation.");
    const fresh = scan({ root, source });
    assert(fresh.characters.every(character => !character.entries.length && !character.migrations.length));
    assert.equal(prepare(root, fresh).outputs.size, 0);
    assert.throws(() => prepare(root, report), /stale/);
});

test("Stale references, target edits and modified metadata are rejected", () => {
    const { root, source, save } = fixture();
    const report = complete(scan({ root, source }));
    const tampered = structuredClone(report);
    tampered.characters[0].entries[0].path = "DESCRIBE.MOD_ITEM";
    assert.throws(() => prepare(root, tampered), /Unknown draft path|Only text/);
    save("scripts/speech_wilson.lua", 'return { NEW = "new" }');
    assert.throws(() => prepare(root, report), /stale/);
    const changedReference = complete(scan({ root, source }));
    save("mod/strings/kiritzuka.lua", 'return { NEW = "user edit" }');
    assert.throws(() => prepare(root, changedReference), /stale/);
});

test("Partial imports skip untouched entries and reject incomplete translations", () => {
    const { root, source } = fixture();
    const report = scan({ root, source, names: ["manutsawee"] });
    const entry = report.characters[0].entries.find(entry => entry.path === "DESCRIBE.NEW");
    entry.text = "A completed line.";
    assert.throws(() => prepare(root, report), /Invalid speech/);
    entry.translation = "A completed translation.";
    const prepared = prepare(root, report);
    assert.equal(prepared.stats[0].imported, 1);
    assert(prepared.stats[0].skipped > 0);
    const result = parseSpeech(prepared.outputs.get("strings/manutsawee.lua")).value;
    assert.equal(get(result, "DESCRIBE.NEW"), "A completed line.");
    assert.equal(get(result, "ANNOUNCE_NEW"), undefined);
});

test("Catalog-only repair leaves existing Lua bytes unchanged", () => {
    const { root, source } = fixture();
    const first = complete(scan({ root, source, names: ["manutsawee"] }));
    write(root, first, prepare(root, first));
    const file = path.join(root, "scripts/languages/chinese_s.po");
    const locale = new Catalog(fs.readFileSync(file, "utf8"));
    locale.set("STRINGS.CHARACTERS.MANUTSAWEE.DESCRIBE.NEW", "Outdated original", "Outdated translation");
    fs.writeFileSync(file, locale.text());
    const report = scan({ root, source, names: ["manutsawee"] });
    assert.equal(report.characters[0].entries.length, 1);
    assert.equal(report.characters[0].entries[0].reason, "catalog");
    assert.equal(report.characters[0].entries[0].translation, "");
    report.characters[0].entries[0].translation = "Correct translation.";
    const prepared = prepare(root, report);
    assert(!prepared.outputs.has("strings/manutsawee.lua"));
});

test("Write rechecks target hashes after preview", () => {
    const { root, source, save } = fixture();
    const report = complete(scan({ root, source }));
    const prepared = prepare(root, report);
    save("mod/strings/kiritzuka.lua", 'return { USER = "New work" }');
    assert.throws(() => write(root, report, prepared), /changed during import/);
    assert(!fs.existsSync(path.join(root, "tools/speech/backups")));
});

test("Catalog contexts pointing at existing state tables block import", () => {
    const { root, source } = fixture();
    const file = path.join(root, "strings/manutsawee.lua");
    fs.writeFileSync(file, fs.readFileSync(file, "utf8").replace('BAT = "Old bat."', 'BAT = { GENERIC = "Old bat." }'));
    const report = scan({ root, source, names: ["manutsawee"] });
    assert(report.characters[0].conflicts.some(conflict => conflict.reason.includes("overwrite a speech table")));
    assert.throws(() => prepare(root, complete(report)), /Resolve type conflicts/);
});

test("Rename failures retain all originals and identify the backup directory", t => {
    const { root, source } = fixture();
    const report = complete(scan({ root, source }));
    const prepared = prepare(root, report);
    const original = fs.readFileSync(path.join(root, "strings/manutsawee.lua"), "utf8");
    const rename = fs.renameSync;
    let count = 0;
    t.mock.method(fs, "renameSync", (...args) => {
        if (++count === 2) throw new Error("Simulated disk error");
        return rename(...args);
    });
    assert.throws(() => write(root, report, prepared), /Originals are in .*backups/);
    const directory = path.join(root, "tools/speech/backups");
    const backup = path.join(directory, fs.readdirSync(directory)[0]);
    assert.equal(fs.readFileSync(path.join(backup, "strings/manutsawee.lua"), "utf8"), original);
    for (const relative of prepared.outputs.keys()) assert(fs.existsSync(path.join(backup, relative)));
});

test("CLI works outside the mod, exports drafts exclusively, and returns check status", () => {
    const { root, source, directory } = fixture();
    const cli = path.resolve(__dirname, "../cli.cjs");
    const run = args => spawnSync(process.execPath, [cli, ...args], { cwd: os.tmpdir(), encoding: "utf8" });
    assert.equal(run(["check", "--root", root, "--source", source]).status, 1);
    const draft = path.join(directory, "draft.json");
    assert.equal(run(["scan", "--root", root, "--source", source, "--output", draft]).status, 0);
    assert.equal(run(["scan", "--root", root, "--source", source, "--output", draft]).status, 2);
    fs.writeFileSync(draft, JSON.stringify(complete(JSON.parse(fs.readFileSync(draft, "utf8")))));
    assert.equal(run(["apply", "--root", root, "--input", draft]).status, 0);
    assert.equal(run(["apply", "--root", root, "--input", draft, "--write"]).status, 0);
    assert.equal(run(["check", "--root", root, "--source", source]).status, 0);
    assert.equal(run(["scan", "--sorce", source]).status, 2);
});

test("audit reports stale, missing, extra, placeholder and unsynced entries", () => {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "dst-speech-audit-"));
    const save = (relative, content) => {
        fs.mkdirSync(path.dirname(path.join(root, relative)), { recursive: true });
        fs.writeFileSync(path.join(root, relative), content);
    };
    save("strings/common.lua", 'return { NAMES = { A = "New", B = "Weight: {weight}", C = "Absent" } }\n');
    for (const name of ["generic", "kiritzuka", "manutsawee"]) save(`strings/${name}.lua`, "return {}\n");
    const entry = (context, id, text) => `msgctxt "STRINGS.NAMES.${context}"\nmsgid "${id}"\nmsgstr "${text}"\n`;
    const locale = [entry("A", "Old", "旧"), entry("B", "Weight: {weight}", "重量：{重量}"), entry("D", "Gone", "没了")].join("\n");
    save("scripts/languages/chinese_s.po", locale);
    save("scripts/languages/strings.pot", [entry("A", "New", ""), entry("B", "Weight: {weight}", ""), entry("C", "Absent", "")].join("\n"));
    save("scripts/languages/chinese_t.po", entry("A", "Old", "舊"));
    const problems = audit(root);
    for (const expected of [
        "STALE scripts/languages/chinese_s.po STRINGS.NAMES.A",
        "MISSING scripts/languages/chinese_s.po STRINGS.NAMES.C",
        "EXTRA scripts/languages/chinese_s.po STRINGS.NAMES.D",
        "PLACEHOLDER scripts/languages/chinese_s.po STRINGS.NAMES.B",
        "UNSYNCED scripts/languages/chinese_t.po STRINGS.NAMES.B",
    ]) assert(problems.includes(expected), expected);
});
