const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const assert = require("node:assert/strict");
const lua = require("luaparse");
const gettext = require("gettext-parser");

const CHARACTERS = {
    manutsawee: { locale: "scripts/languages/chinese_s.po", pot: "scripts/languages/strings.pot" },
    kiritzuka: { locale: "scripts/languages/chinese_s.po", pot: "scripts/languages/strings.pot" },
};
const own = (object, key) => Object.prototype.hasOwnProperty.call(object, key);
const isTable = value => value !== null && typeof value === "object";
const blank = value => typeof value === "string" && !value.trim();
const placeholder = value => typeof value === "string" && value.startsWith("only_used_by");
const shared = value => typeof value === "string" && !placeholder(value);
const hash = text => crypto.createHash("sha256").update(text).digest("hex");
const quote = text => JSON.stringify(text);
const compare = (a, b) => /^\d+$/.test(a) && /^\d+$/.test(b)
    ? Number(a) - Number(b) : a < b ? -1 : a > b ? 1 : 0;

function fields(node) {
    let index = 0;
    return node.fields.map(field => {
        let key;
        if (field.type === "TableValue") key = String(++index);
        else if (field.type === "TableKeyString") key = field.key.name;
        else if (field.key.type === "NumericLiteral") key = String(field.key.value);
        else throw new Error("Speech tables must use identifier or numeric keys.");
        assert(/^[A-Za-z_][A-Za-z0-9_]*$|^[1-9][0-9]*$/.test(key), `Unsupported speech key: ${key}`);
        assert(!["__proto__", "constructor", "prototype"].includes(key), `Unsupported speech key: ${key}`);
        return { field, key };
    });
}

function nodeValue(node) {
    if (node.type === "StringLiteral") {
        // Parse UTF-8 as Lua bytes; keep the original AST ranges in JavaScript code units.
        const literal = Buffer.from(node.raw, "utf8").toString("latin1");
        const parsed = lua.parse("return " + literal, { encodingMode: "pseudo-latin1" });
        return Buffer.from(parsed.body[0].arguments[0].value, "latin1").toString("utf8");
    }
    assert.equal(node.type, "TableConstructorExpression", "Speech must contain only literal tables and strings.");
    const result = {};
    for (const { field, key } of fields(node)) {
        assert(!own(result, key), `Duplicate Lua key: ${key}`);
        result[key] = nodeValue(field.value);
    }
    return result;
}

function parseSpeech(source) {
    const ast = lua.parse(source, { ranges: true, luaVersion: "5.1" });
    assert.equal(ast.body.length, 1, "Expected a single literal return table; executable Lua is not supported.");
    assert.equal(ast.body[0].type, "ReturnStatement", "Expected a return table.");
    assert.equal(ast.body[0].arguments.length, 1, "Expected one return value.");
    const node = ast.body[0].arguments[0];
    assert.equal(node.type, "TableConstructorExpression", "Expected a return table.");
    return { source, node, value: nodeValue(node) };
}

function get(table, context) {
    return context.split(".").reduce((value, key) =>
        isTable(value) && own(value, key) ? value[key] : undefined, table);
}

function put(table, context, value) {
    const keys = context.split(".");
    let current = table;
    for (const key of keys.slice(0, -1)) {
        assert(/^[A-Za-z_][A-Za-z0-9_]*$|^[1-9][0-9]*$/.test(key), `Invalid key: ${key}`);
        current = current[key] ??= {};
        assert(isTable(current), `Not a table: ${context}`);
    }
    current[keys.at(-1)] = value;
}

function leaves(table, prefix = "", result = new Map()) {
    for (const key of Object.keys(table).sort(compare)) {
        const context = prefix ? `${prefix}.${key}` : key;
        if (isTable(table[key])) leaves(table[key], context, result);
        else result.set(context, table[key]);
    }
    return result;
}

function hasShared(value) {
    return isTable(value) ? Object.values(value).some(hasShared) : shared(value);
}

function randomPool(value) {
    const keys = Object.keys(value);
    return keys.length > 0 && keys.every((_, index) => own(value, String(index + 1)))
        && Object.values(value).every(line => shared(line) && !blank(line));
}

function analyze(reference, speech) {
    const normalized = structuredClone(speech);
    const migrations = [];
    const conflicts = [];
    const missing = [];
    let count = 0;
    function visit(base, target, prefix = "") {
        for (const key of Object.keys(base).sort(compare)) {
            const value = base[key];
            if (!hasShared(value)) continue;
            const context = prefix ? `${prefix}.${key}` : key;
            let actual = target[key];
            if (isTable(value)) {
                if (typeof actual === "string") {
                    if (shared(value.GENERIC)) {
                        migrations.push(context);
                        actual = target[key] = { GENERIC: actual };
                    } else {
                        conflicts.push({ path: context, reason: "String cannot be migrated without a shared GENERIC state." });
                        continue;
                    }
                }
                if (actual === undefined) actual = target[key] = {};
                visit(value, actual, context);
            } else {
                count++;
                if (actual === undefined || blank(actual) || placeholder(actual)) {
                    missing.push({
                        path: context,
                        reason: actual === undefined ? "missing" : placeholder(actual) ? "placeholder" : "empty",
                        reference: value,
                        text: "",
                    });
                } else if (isTable(actual) && !randomPool(actual)) {
                    conflicts.push({ path: context, reason: "Expected a string or a dense, nonempty random speech pool." });
                }
            }
        }
    }
    visit(reference, normalized);
    return { normalized, migrations, conflicts, missing, count };
}

function render(value, depth, eol) {
    if (typeof value === "string") return quote(value);
    const indent = "    ".repeat(depth);
    return "{" + eol + Object.keys(value).sort(compare).map(key =>
        indent + "    " + (/^\d+$/.test(key) ? `[${key}]` : key)
        + " = " + render(value[key], depth + 1, eol) + "," + eol
    ).join("") + indent + "}";
}

function rewriteSpeech(parsed, desired) {
    const { source } = parsed;
    const eol = source.includes("\r\n") ? "\r\n" : "\n";
    const edits = [];
    const insertions = new Map();
    const insert = (offset, text) => insertions.set(offset, (insertions.get(offset) ?? "") + text);
    function visit(node, value, depth) {
        if (node.type !== "TableConstructorExpression") {
            if (nodeValue(node) !== value) edits.push([node.range[0], node.range[1], render(value, depth, eol)]);
            return;
        }
        const entries = fields(node);
        const present = new Set(entries.map(entry => entry.key));
        const added = Object.keys(value).filter(key => !present.has(key)).sort(compare);
        // Compact tables cannot accept line-based insertions without losing surrounding syntax.
        if (added.length && !source.slice(node.range[0], node.range[1]).includes("\n")) {
            edits.push([node.range[0], node.range[1], render(value, depth, eol)]);
            return;
        }
        for (const { field, key } of entries) {
            assert(own(value, key), `Refusing to remove an existing key: ${key}`);
            visit(field.value, value[key], depth + 1);
        }
        if (added.length && entries.length) {
            const last = entries.at(-1).field;
            const tail = source.slice(last.range[1], node.range[1] - 1);
            if (!/^\s*[,;]/.test(tail)) insert(last.range[1], ",");
        }
        for (const key of added) {
            const next = entries.find(entry => compare(entry.key, key) > 0);
            const offset = next ? next.field.range[0] : node.range[1] - 1;
            const lineStart = source.lastIndexOf("\n", offset - 1) + 1;
            assert(/^[ \t]*$/.test(source.slice(lineStart, offset)), "Expand inline Lua fields onto separate lines before importing.");
            insert(lineStart, "    ".repeat(depth + 1) + (/^\d+$/.test(key) ? `[${key}]` : key)
                + " = " + render(value[key], depth + 1, eol) + "," + eol);
        }
    }
    visit(parsed.node, desired, 0);
    for (const [offset, text] of insertions) edits.push([offset, offset, text]);
    let result = source;
    for (const [start, end, text] of edits.sort((a, b) => b[0] - a[0] || b[1] - a[1])) {
        result = result.slice(0, start) + text + result.slice(end);
    }
    assert.deepEqual(parseSpeech(result).value, desired, "Lua rewrite changed unexpected values.");
    return result;
}

class Catalog {
    constructor(source) {
        this.eol = source.includes("\r\n") ? "\r\n" : "\n";
        this.parts = source.split(/(\r?\n[ \t]*\r?\n)/);
        this.entries = new Map();
        for (let index = 0; index < this.parts.length; index += 2) {
            const block = this.parts[index];
            const declarations = block.match(/^msgctxt\s/gm) ?? [];
            if (!declarations.length) continue;
            const parsed = gettext.po.parse(Buffer.from(block), { defaultCharset: "utf-8" });
            const entries = Object.entries(parsed.translations).filter(([context]) => context)
                .flatMap(([, entries]) => Object.values(entries));
            assert.equal(declarations.length, entries.length, "Duplicate or malformed PO contexts.");
            assert.equal(entries.length, 1, "Separate PO entries with blank lines before importing.");
            const entry = entries[0];
            assert(!this.entries.has(entry.msgctxt), `Duplicate PO context: ${entry.msgctxt}`);
            assert(!entry.msgid_plural, "Plural speech entries are not supported.");
            this.entries.set(entry.msgctxt, { index, ...entry });
        }
    }

    set(context, english, translation, oldContext = context) {
        const old = this.entries.get(oldContext);
        if (oldContext !== context) assert(!this.entries.has(context), `PO migration collision: ${context}`);
        if (old && oldContext === context && old.msgid === english && old.msgstr[0] === translation) return;
        const index = old?.index ?? this.parts.length;
        let comments = old ? this.parts[index].split(/\r?\n/).filter(line => line.startsWith("#")) : [`#. ${context}`];
        comments = comments.map(line => line.replaceAll(oldContext, context));
        const block = [...comments, `msgctxt ${quote(context)}`, `msgid ${quote(english)}`, `msgstr ${quote(translation)}`].join(this.eol);
        if (old) this.parts[index] = block + (this.parts[index].endsWith("\n") ? this.eol : "");
        else this.parts.push(this.eol + this.eol, block);
        this.entries.delete(oldContext);
        this.entries.set(context, { index: old ? index : index + 1, msgctxt: context, msgid: english, msgstr: [translation] });
    }

    migrate(from, to) {
        const entry = this.entries.get(from);
        if (entry) this.set(to, entry.msgid, entry.msgstr[0], from);
    }

    text() {
        return this.parts.join("");
    }
}

function prefix(name) {
    return `STRINGS.CHARACTERS.${name.toUpperCase()}.`;
}

function snapshot(root, relative, files) {
    const source = fs.readFileSync(path.join(root, relative), "utf8");
    files[relative] = hash(source);
    return source;
}

function scan({ root, source, names = Object.keys(CHARACTERS) }) {
    const referencePath = path.resolve(source, "speech_wilson.lua");
    const referenceSource = fs.readFileSync(referencePath, "utf8");
    const reference = parseSpeech(referenceSource).value;
    const translationPath = path.resolve(source, "languages/chinese_s.po");
    const nativeTranslations = fs.existsSync(translationPath)
        ? new Catalog(fs.readFileSync(translationPath, "utf8")) : null;
    const files = {};
    const characters = [];
    assert(names.length && new Set(names).size === names.length, "Select distinct characters.");
    for (const name of names) {
        assert(own(CHARACTERS, name), `Unknown character: ${name}`);
        const config = CHARACTERS[name];
        const speech = parseSpeech(snapshot(root, `strings/${name}.lua`, files));
        const result = analyze(reference, speech.value);
        const entries = result.missing;
        if (config.locale) {
            const locale = new Catalog(snapshot(root, config.locale, files));
            const pot = new Catalog(snapshot(root, config.pot, files));
            for (const context of result.migrations) {
                locale.migrate(prefix(name) + context, prefix(name) + context + ".GENERIC");
                pot.migrate(prefix(name) + context, prefix(name) + context + ".GENERIC");
            }
            for (const [filename, catalog] of [[config.locale, locale], [config.pot, pot]]) {
                for (const context of catalog.entries.keys()) {
                    if (!context.startsWith(prefix(name))) continue;
                    const speechPath = context.slice(prefix(name).length);
                    if (isTable(get(result.normalized, speechPath))) {
                        result.conflicts.push({
                            path: speechPath,
                            reason: `${filename}: this translation context would overwrite a speech table; migrate it to a leaf context.`,
                        });
                    }
                }
            }
            const missingPaths = new Set(entries.map(entry => entry.path));
            for (const [context, original] of leaves(reference)) {
                const text = get(result.normalized, context);
                if (!shared(original) || missingPaths.has(context) || typeof text !== "string") continue;
                const translated = locale.entries.get(prefix(name) + context);
                const template = pot.entries.get(prefix(name) + context);
                if (!translated || blank(translated.msgstr[0]) || translated.msgid !== text || template?.msgid !== text) {
                    entries.push({
                        path: context, reason: "catalog", reference: original, text,
                        translation: translated?.msgid === text ? translated.msgstr[0] : "",
                        previousText: translated?.msgid ?? "",
                        previousTranslation: translated?.msgstr[0] ?? "",
                    });
                }
            }
        }
        for (const entry of entries) {
            entry.referenceTranslation = nativeTranslations?.entries.get("STRINGS.CHARACTERS.GENERIC." + entry.path)?.msgstr[0] ?? "";
            if (config.locale) entry.translation ??= "";
        }
        entries.sort((a, b) => compare(a.path, b.path));
        characters.push({ name, sharedContexts: result.count, migrations: result.migrations, conflicts: result.conflicts, entries });
    }
    return {
        version: 1,
        reference: { path: referencePath, sha256: hash(referenceSource) },
        files,
        characters,
    };
}

function validateText(text, reference, context) {
    assert(typeof text === "string" && !blank(text) && !placeholder(text), `Invalid speech: ${context}`);
    assert(!/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(text), `Control character in ${context}`);
    const tokens = value => ({
        printf: value.match(/%(?:\d+\$)?[-+#0 ]*(?:\d+|\*)?(?:\.\d+)?[cdeEfgGiouXxsq%]/g) ?? [],
        named: (value.match(/\{[A-Za-z_][A-Za-z0-9_]*\}/g) ?? []).sort(),
    });
    assert.deepEqual(tokens(text), tokens(reference), `Keep formatting placeholders in ${context}`);
}

function prepare(root, draft) {
    assert.equal(draft.version, 1, "Unsupported draft version.");
    assert(Array.isArray(draft.characters), "Invalid draft characters.");
    const current = scan({
        root,
        source: path.dirname(draft.reference.path),
        names: draft.characters.map(character => character.name),
    });
    assert.deepEqual(draft.files, current.files, "Draft is stale: a target or catalog changed. Scan again.");
    assert.deepEqual(draft.reference, current.reference, "Draft is stale: speech_wilson.lua changed. Scan again.");
    const metadata = structuredClone(draft);
    for (const character of metadata.characters) {
        const expected = current.characters.find(item => item.name === character.name);
        for (const entry of character.entries) {
            const original = expected.entries.find(item => item.path === entry.path);
            assert(original, `Unknown draft path: ${character.name}.${entry.path}`);
            entry.text = original.text;
            if (own(original, "translation")) entry.translation = original.translation;
        }
    }
    assert.deepEqual(metadata, current, "Only text and translation fields may be edited. Scan again after structural changes.");
    const outputs = new Map();
    const stats = [];
    // Characters share catalog files, so every import must accumulate in one instance.
    const catalogs = new Map();
    const loadCatalog = relative => {
        if (!catalogs.has(relative)) catalogs.set(relative, new Catalog(fs.readFileSync(path.join(root, relative), "utf8")));
        return catalogs.get(relative);
    };
    for (const character of draft.characters) {
        assert(!character.conflicts.length, `Resolve type conflicts in ${character.name} before importing.`);
        const name = character.name;
        const config = CHARACTERS[name];
        const relative = `strings/${name}.lua`;
        const source = parseSpeech(fs.readFileSync(path.join(root, relative), "utf8"));
        const desired = structuredClone(source.value);
        const locale = config.locale ? loadCatalog(config.locale) : null;
        const pot = config.pot ? loadCatalog(config.pot) : null;
        for (const context of character.migrations) {
            const text = get(desired, context);
            put(desired, context, { GENERIC: text });
            for (const catalog of [locale, pot]) catalog?.migrate(prefix(name) + context, prefix(name) + context + ".GENERIC");
        }
        let imported = 0;
        for (const entry of character.entries) {
            assert(typeof entry.text === "string", `text must be a string: ${entry.path}`);
            if (locale) assert(typeof entry.translation === "string", `translation must be a string: ${entry.path}`);
            if (blank(entry.text)) {
                assert(!locale || blank(entry.translation), `Translation has no speech text: ${entry.path}`);
                continue;
            }
            if (entry.reason === "catalog") {
                assert.equal(entry.text, get(desired, entry.path), `Cannot replace existing speech: ${entry.path}`);
                if (blank(entry.translation)) continue;
            }
            validateText(entry.text, entry.reason === "catalog" ? entry.text : entry.reference, entry.path);
            if (locale) validateText(entry.translation, entry.text, entry.path + " (translation)");
            const existing = get(desired, entry.path);
            assert(existing === undefined || blank(existing) || placeholder(existing) || existing === entry.text,
                `Cannot replace existing speech: ${entry.path}`);
            put(desired, entry.path, entry.text);
            locale?.set(prefix(name) + entry.path, entry.text, entry.translation);
            pot?.set(prefix(name) + entry.path, entry.text, "");
            imported++;
        }
        outputs.set(relative, rewriteSpeech(source, desired));
        if (locale) outputs.set(config.locale, locale.text());
        if (pot) outputs.set(config.pot, pot.text());
        stats.push({ name, imported, skipped: character.entries.length - imported, migrations: character.migrations.length });
    }
    for (const [relative, content] of outputs) {
        if (hash(content) === draft.files[relative]) outputs.delete(relative);
    }
    return { outputs, stats };
}

function write(root, draft, prepared) {
    // Validate all inputs before creating backups or replacing any repository file.
    for (const [relative, expected] of Object.entries(draft.files)) {
        assert.equal(hash(fs.readFileSync(path.join(root, relative), "utf8")), expected, `File changed during import: ${relative}`);
    }
    assert.equal(hash(fs.readFileSync(draft.reference.path, "utf8")), draft.reference.sha256, "Reference changed during import.");
    if (!prepared.outputs.size) return null;
    const id = new Date().toISOString().replaceAll(":", "-") + "-" + crypto.randomBytes(4).toString("hex");
    const backup = path.join(root, "tools/speech/backups", id);
    const staged = [];
    try {
        for (const [relative, content] of prepared.outputs) {
            const destination = path.join(root, relative);
            const saved = path.join(backup, relative);
            fs.mkdirSync(path.dirname(saved), { recursive: true });
            fs.copyFileSync(destination, saved, fs.constants.COPYFILE_EXCL);
            const temporary = destination + ".speech-" + id + ".tmp";
            fs.writeFileSync(temporary, content, { flag: "wx", mode: fs.statSync(destination).mode });
            staged.push({ destination, temporary });
        }
        for (const [relative, expected] of Object.entries(draft.files)) {
            assert.equal(hash(fs.readFileSync(path.join(root, relative), "utf8")), expected, `File changed during staging: ${relative}`);
        }
        for (const item of staged) fs.renameSync(item.temporary, item.destination);
    } catch (error) {
        throw new Error(`Import could not finish. Originals are in ${backup}; inspect targets and .speech-*.tmp files before retrying.\n${error.message}`);
    }
    return backup;
}

const STRING_FILES = {
    common: "STRINGS",
    kiritzuka_variants: "STRINGS.KIRITZUKA_SPEECH_VARIANTS",
    manutsawee_variants: "STRINGS.MANUTSAWEE_SPEECH_VARIANTS",
};
const LOCALE = "scripts/languages/chinese_s.po";
const TEMPLATE = "scripts/languages/strings.pot";
const TRADITIONAL = "scripts/languages/chinese_t.po";
const placeholders = text => (text.match(/%[sd]|\{\w+\}/g) ?? []).sort().join();

// Every English string must have one catalog entry; scan() only covers speech shared with the game.
function audit(root) {
    const english = new Map();
    const directory = path.join(root, "strings");
    for (const file of fs.readdirSync(directory)) {
        if (path.extname(file) !== ".lua") continue;
        const name = path.basename(file, ".lua");
        const base = STRING_FILES[name] ?? (/^[a-z][a-z0-9]*$/.test(name) ? `STRINGS.CHARACTERS.${name.toUpperCase()}` : null);
        if (base === null) continue;
        const strings = parseSpeech(fs.readFileSync(path.join(directory, file), "utf8")).value;
        for (const [context, value] of leaves(strings)) english.set(`${base}.${context}`, value);
    }
    const load = relative => new Catalog(fs.readFileSync(path.join(root, relative), "utf8")).entries;
    const problems = [];
    const locale = load(LOCALE);
    for (const [relative, entries] of [[LOCALE, locale], [TEMPLATE, load(TEMPLATE)]]) {
        for (const [context, value] of english) {
            const entry = entries.get(context);
            if (!entry) problems.push(`MISSING ${relative} ${context}`);
            else if (entry.msgid !== value) problems.push(`STALE ${relative} ${context}`);
        }
        for (const context of entries.keys()) {
            if (!english.has(context)) problems.push(`EXTRA ${relative} ${context}`);
        }
    }
    for (const [context, entry] of locale) {
        if (placeholders(entry.msgid) !== placeholders(entry.msgstr[0])) problems.push(`PLACEHOLDER ${LOCALE} ${context}`);
    }
    const traditional = load(TRADITIONAL);
    for (const [context, entry] of locale) {
        if (traditional.get(context)?.msgid !== entry.msgid) problems.push(`UNSYNCED ${TRADITIONAL} ${context}`);
    }
    for (const context of traditional.keys()) {
        if (!locale.has(context)) problems.push(`EXTRA ${TRADITIONAL} ${context}`);
    }
    return problems;
}

module.exports = { CHARACTERS, parseSpeech, analyze, rewriteSpeech, Catalog, scan, prepare, write, get, hash, validateText, audit };
