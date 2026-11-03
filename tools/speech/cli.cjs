#!/usr/bin/env node
const fs = require("node:fs");
const path = require("node:path");
const { scan, prepare, write, audit } = require("./lib.cjs");

const help = `Usage:
  node tools/speech/cli.cjs scan --source <DST scripts> [--output <draft.json>]
  node tools/speech/cli.cjs check --source <DST scripts>
  node tools/speech/cli.cjs apply --input <draft.json> [--write]

Options:
  --character <name>  Select manutsawee or kiritzuka; repeat to select both.
  --root <directory>  Mod root (defaults to this tool's repository).
  --help             Show this help.

Scan exports empty text fields with Wilson references. Edit only text/translation.
Apply previews changes by default. --write creates backups and updates files.
Existing drafts are never overwritten. No network requests or Lua execution.
Exit codes: 0 = success; 1 = check found pending work; 2 = invalid input/error.`;

function main() {
    const args = process.argv.slice(2);
    if (!args.length || args.includes("--help") || args.includes("-h")) {
        console.log(help);
        return;
    }
    const command = args.shift();
    if (!["scan", "check", "apply"].includes(command)) throw new Error(`Unknown command: ${command}`);
    const options = { root: path.resolve(__dirname, "../.."), names: [] };
    const allowed = command === "apply" ? ["--root", "--input", "--write"]
        : ["--root", "--source", "--character", ...(command === "scan" ? ["--output"] : [])];
    while (args.length) {
        const flag = args.shift();
        if (!allowed.includes(flag)) throw new Error(`Unknown option for ${command}: ${flag}`);
        if (flag === "--write") options.write = true;
        else {
            const value = args.shift();
            if (!value || value.startsWith("--")) throw new Error(`Missing value for ${flag}`);
            if (flag === "--character") options.names.push(value);
            else options[flag.slice(2)] = value;
        }
    }
    options.root = path.resolve(options.root);
    if (command === "apply") {
        if (!options.input) throw new Error("--input is required.");
        const draft = JSON.parse(fs.readFileSync(options.input, "utf8"));
        const prepared = prepare(options.root, draft);
        for (const stat of prepared.stats) {
            console.log(`${stat.name}: import=${stat.imported}, skipped=${stat.skipped}, migrations=${stat.migrations}`);
        }
        for (const relative of prepared.outputs.keys()) console.log(`${options.write ? "UPDATE" : "PREVIEW"} ${relative}`);
        if (options.write) {
            const backup = write(options.root, draft, prepared);
            console.log(backup ? `Backup: ${backup}` : "No file changes.");
        } else console.log("Preview only. Add --write to import.");
        return;
    }
    if (!options.source) throw new Error("--source is required; use the extracted DST scripts directory.");
    if (!options.names.length) delete options.names;
    const report = scan(options);
    let pending = 0;
    for (const character of report.characters) {
        const { name, sharedContexts, entries, migrations, conflicts } = character;
        pending += entries.length + migrations.length + conflicts.length;
        console.log(`${name}: shared=${sharedContexts}, pending=${entries.length}, migrations=${migrations.length}, conflicts=${conflicts.length}`);
        for (const conflict of conflicts) console.log(`CONFLICT ${name}.${conflict.path}: ${conflict.reason}`);
        if (!options.output) for (const entry of entries) console.log(`${entry.reason.toUpperCase()} ${name}.${entry.path}`);
    }
    if (options.output) {
        fs.writeFileSync(options.output, JSON.stringify(report, null, 2) + "\n", { flag: "wx" });
        console.log(`Draft: ${path.resolve(options.output)}`);
    }
    if (command === "check") {
        const problems = fs.existsSync(path.join(options.root, "strings/common.lua")) ? audit(options.root) : [];
        console.log(`catalog audit: problems=${problems.length}`);
        for (const problem of problems) console.log(problem);
        if (pending || problems.length) process.exitCode = 1;
    }
}

try {
    main();
} catch (error) {
    console.error(error.message);
    process.exitCode = 2;
}
