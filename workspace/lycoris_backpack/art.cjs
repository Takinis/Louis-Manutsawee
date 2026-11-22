const fs = require("node:fs");
const path = require("node:path");
const sharp = require("sharp");

const ink = "#241b19";
const shade = "#382923";
const edge = "#a67d60";
const thread = "#b28c6e";
const strap = "#48372e";
const flap = "M6 28 Q6.5 22 13 20 Q34 18 53 18.5 L76 17 Q84 17 86.5 23 L87 36 L89 52 Q89 56.5 82 58.5 L58 59 L13 61.5 Q6 63 5.5 56 L6.5 42 Z";
const body = "M10 29 L84 23 L86 52 L88 74 Q89 82 80 85 L61 85 L18 87 Q8 88 6 79 L7 59 L7 39 Z";

const line = (d, color, width, attrs = "") =>
    `<path d="${d}" fill="none" stroke="${color}" stroke-width="${width}" ${attrs} />`;
const shape = (d, color, width = 2.8, outline = ink) =>
    `<path d="${d}" fill="${color}" stroke="${outline}" stroke-width="${width}" />`;
const fill = (d, color, opacity = 1) =>
    `<path d="${d}" fill="${color}" opacity="${opacity}" />`;
const stitch = (d, phase = 0) =>
    line(d, "#2a201c", 1.05, `stroke-dasharray="1.35 2.6" stroke-dashoffset="${phase}"`) +
    line(d, thread, 0.67, `stroke-dasharray="1.1 2.85" stroke-dashoffset="${phase + 0.5}"`);

const defs = `<defs>
    <linearGradient id="flap" x1=".16" y1=".05" x2=".92" y2=".91">
        <stop stop-color="#986e52"/><stop offset=".55" stop-color="#79533e"/><stop offset="1" stop-color="#583c31"/>
    </linearGradient>
    <linearGradient id="body" x1=".08" y1=".9" x2=".84" y2=".1">
        <stop stop-color="#765039"/><stop offset=".56" stop-color="#5b4033"/><stop offset="1" stop-color="#3b2b26"/>
    </linearGradient>
    <linearGradient id="gusset" x1=".94" y1=".2" x2=".1" y2=".64">
        <stop stop-color="#74523c"/><stop offset=".53" stop-color="#563d2e"/><stop offset="1" stop-color="#342824"/>
    </linearGradient>
    <linearGradient id="metal" x1=".2" y1=".04" x2=".78" y2=".88">
        <stop stop-color="#e0c4a0"/><stop offset=".38" stop-color="#ad9270"/><stop offset=".69" stop-color="#79674f"/>
        <stop offset="1" stop-color="#c3a37b"/>
    </linearGradient>
    <pattern id="grain" width="24" height="21" patternUnits="userSpaceOnUse">
        <path d="M2 3l2 -.4m3 11 1 -.7m7 -9 3 -.6m-3 13 2 -.8m4 5 1 -.1m-21 -2 3 -.7m18 -10 1 -.3"
            fill="none" stroke="#2d211f" stroke-width=".55" opacity=".37"/>
        <path d="M5 6l1 -.15m4 3 2 -.6m6 4 1 -.4m-7 7 1 -.4m7 -18 2 -.2"
            fill="none" stroke="#d4a98a" stroke-width=".52" opacity=".42"/>
    </pattern>
</defs>`;

function panel(d, paint, width = 2.9) {
    return shape(d, `url(#${paint})`, width) + fill(d, "url(#grain)");
}

function buckle(x, y, angle) {
    const ring = "M-4.8 -3.5 Q-5.5 -6 -2.4 -6.4 L2.1 -6.7 Q4.9 -6.5 5 -3.9 L4.6 3.3 Q4.4 5.8 2 6.2 L-1.7 6.4 Q-4.7 6 -4.8 3.2 Z";
    return `<g transform="translate(${x} ${y}) rotate(${angle})">
        ${line(ring, ink, 4.3)}
        ${line(ring, "url(#metal)", 2.65)}
        ${line("M-4 -2 Q-4.7 -5.5 -1 -5.8 L1.3 -5.9 M3.7 4.1 L2.5 5.2", "#e6c9a2", 0.84)}
        ${line("M-.5 -1.8 Q-.9 1 -.5 3.8", ink, 2.3)}
        ${line("M-.7 -2.6 Q-1.2 .4 -.6 3.6", "#baa181", 1.25)}
    </g>`;
}

function tab(d, wear, seam) {
    return shape(d, strap, 1.85) + fill(d, "url(#grain)") +
        fill(wear, "#917255", 0.6) + stitch(seam);
}

function front(flat = false) {
    return `
        ${shape("M33 22 Q30 9 42 6 Q56 1 63 11 Q65 15 66 21 L60 22 Q56 10 47 12 Q37 13 39 23 Z", strap, 2.3)}
        ${fill("M34 15 Q36 6 50 6.5 Q55 6.5 59 10.5 Q49 6.8 41 10 Q37 11 34 15Z", edge)}
        ${line("M34 19 L35 21 M61 17 L62 19", "url(#metal)", 2.3)}
        ${flat ? "" : `
            ${panel("M75 21 L89 17 Q98 16 100 26 L98 69 Q99 78 93 81 L83 85 L74 81 Z", "gusset")}
            ${fill("M86 24 Q91 20 96 23 L95 31 L94 66 Q94 76 90 80 L87 79 Q92 67 90 50Z", shade)}
            ${line("M96 27 Q96 36 95 40 L94 70 M95 73 Q94 78 91 78", edge, 0.95)}
            ${line("M91 40 Q91 47 90.5 51 M92 44 L91 62 M93 49 L92 70", "#2d2420", 0.83)}
            ${line("M92 28 q3 -2 3 2 l-1 3 q-1 1 -2 -1 z", "url(#metal)", 1.45)}
        `}
        ${panel(body, "body", 3.05)}
        ${fill("M8 63 Q10 78 16 80 Q35 85 58 81 L77 79 Q83 78 85 74 Q87 82 78 84 L59 84 L18 86 Q9 86 7 78Z", "#2a201c", 0.76)}
        ${shape("M15 53 Q42 51 74 50 L79 73 Q79 80 73 80 L22 82 Q14 82 13 76 Z", "url(#body)", 1.7)}
        ${fill("M14 58 L79 54 L79 63 Q69 63 53 62 L14 66 Z", "#221a19", 0.57)}
        ${stitch("M17 66 L16 74 Q16 79 22 79 L43 78 L71 77 Q75 77 75 73 L74 63")}
        ${line("M8 77 Q9 82 15 83 M20 84 L35 84 M55 84 L76 82", "#94684e", 0.8)}
        ${panel(flap, "flap", 2.7)}
        ${fill("M6.7 48 Q7.5 56 13 57 Q29 58 43 55 Q63 55 79 52 Q85 51 87 47 L88 53 Q88 56 81 58 L52 59 L13 61 Q7 62 6.6 57 Z", "#3a2923", 0.48)}
        ${fill("M8 31 Q8.5 22 16 21 Q28 20 40 20 Q55 21 75 18 Q82 18 85 23 Q79 20 71 22 L39 23 Q13 23 10 29 L8 37 Z", "#bd8f6a", 0.69)}
        ${line("M12 25 Q10 35 10 42 M10 46 L9.8 53 Q9.5 57 15 57 M20 57 L41 56 M48 56 L78 54 Q83 54 84 51", "#3f2e25", 1.05)}
        ${stitch("M13 27 Q12 39 12 52 Q12 56 18 55 L47 54 L78 52 Q82 52 82 48 L81 32", 0.65)}
        ${fill("M9 33 L21 27 L19 29 L9 36 Z M9 40 L19 33 L18 35 L9 42 Z M10 45 L17 40 L16 42 L10 47 Z", "#492f26", 0.49)}
        ${line("M36 27 Q41 26 44 27 M34 29 L38 28 M60 45 L64 44 M15 47 L18 46 M15 49 L19 47 M75 47 L79 44 M76 49 L80 47", "#4c342a", 0.86)}
        ${line("M34 73 L38 72 M30 75 L35 74 M57 74 L65 72 M59 76 L63 75", "#89634a", 0.95)}
        ${tab("M22 20 Q27 18 32 20 L30 47 L29 66 Q28 71 23 75 Q20 72 19.5 68 L21 51 Z",
            "M23 24 L25 22 L23 48 Q22 52 21 62 L21 47Z", "M25 23 L23 62 Q22 67 23 71")}
        ${tab("M64 18 Q68 17 73 18 L74 45 L74 66 Q73 70 70 73 Q66 71 64.5 65 L65 44 Z",
            "M65.5 21 L67.5 20.5 L67 40 L67 50 L65.7 45 Z", "M67 22 L67 44 L67 63 Q68 68 70 70")}
        ${buckle(25, 57, 3)}
        ${buckle(69.5, 55, -4)}
        ${shape("M46 29.5 Q54 29 56 36 Q59 44 51 47 Q43 50 39 44 Q35 38 40 33 Q42 30 46 29.5 Z", "#815c48", 1.25, "#4c3229")}
        ${line("M39.5 36 Q42 29.8 48.5 31 Q53 31.4 54.8 35", "#b1886b", 0.97)}
        ${fill("M41 35 Q45 31 50 34 Q56 37 52 42 Q50 45 46 45.5 Q51 43 51 39 Q51 34 41 35Z", "#392822")}
        ${fill("M42 37 Q47 34.7 49 38 Q51 41.5 46 44 Q48 41 47 39.5 Q46 38 42 37Z M42 44 Q40 42 43 40 Q42.5 42 45 42.5 Q44 44 42 44Z", "#4d352b")}
        ${shape("M38 65 Q43 64 56 63.5 L56 71 L38.5 72.5 Z", "#76533d", 1.25, shade)}
        ${shape("M41 67 L53 66 L53 69 L41 70 Z", "#4d382d", 0.85, "#402c24")}
        ${line("M40 71 L54 70", "#aa7d5c", 0.7)}
        ${line("M22.5 65 L23 65.2 M69.4 63 L70.1 63", ink, 1.6)}
    `;
}

function profile() {
    return `
        ${shape("M21 19 Q20 7 31 6 Q38 6 41 16 L36 18 Q34 11 30 12 Q26 12 27 20 Z", strap, 2.3)}
        ${line("M23 13 Q25 7.5 32 7.5 M36 16 L37 17", edge, 1.4)}
        ${panel("M13 27 L39 19 L46 24 L44 64 Q45 79 36 82 L13 84 Q7 84 8 76 L8 39 Z", "gusset", 3.1)}
        ${panel("M10 29 L31 22 L33 45 L33 74 Q33 79 29 80 L13 83 Q7 84 8 76 Z", "body", 2.2)}
        ${fill("M32 50 L42 46 L41 70 Q41 75 36 78 L35 75 L36 56Z", shade)}
        ${line("M41 48 Q40 62 40 69 Q40 75 37 77", edge, 1.14)}
        ${line("M35 53 L37 69 M36 52 L38 65 M35 61 L37 73 M33 70 L34 75", "#291f1c", 0.83)}
        ${panel("M8 28 Q9 22 14 22 L38 16 Q45 14 46 22 L46 43 Q47 47 44 49 L36 52 L13 59 Q7 61 7 55 L7.5 38 Z", "flap")}
        ${fill("M9 33 Q9 23 15 23 L38 17 Q43 16 44 20 Q40 18 34 21 L14 26 Q11 27 9 33Z", "#b58a68", 0.78)}
        ${fill("M8 48 Q10 56 15 54 L36 48 Q43 46 45 43 L45 48 L36 51 L13 58 Q8 60 8 55Z", shade, 0.64)}
        ${stitch("M12 28 L11 51 Q11 55 15 54 L34 49 L41 46 Q43 45 43 40 L42 24", 1)}
        ${line("M24 30 L30 27 M25 32 L29 30 M35 41 L40 38 M33 44 L38 41", "#51392e", 0.86)}
        ${line("M13 62 Q12 71 12 76 Q12 80 16 79 L27 76 M32 56 L32 71", "#291f1c", 1.25)}
        ${stitch("M15 65 L14 74 Q14 77 17 77 L26 74", 0.4)}
        ${tab("M15 24 Q18 22 22 22 L21 44 L20 61 Q20 66 17 69 L13 65 Z",
            "M15.7 25 L17.5 24 L16.4 45 L14.5 48 Z", "M18 26 L16 62 L17 66")}
        ${buckle(17, 54, 3)}
        ${line("M38 52 Q41 49 42 53 L41 56 Q39 57 38 55 Z", "url(#metal)", 1.45)}
    `;
}

function band(d) {
    return `
        ${line(d, ink, 10)}
        ${line(d, "#503b2e", 6.7)}
        ${line(d, "#8c6b52", 2.8)}
        ${line(d, "#a28162", 0.82, 'stroke-dasharray="1.1 3.4"')}
    `;
}
const frontBands = [
    ["M29 10 Q16 11 14 43", "M44 10 Q57 11 59 43"],
    ["M29 10 Q17 12 20 46", "M46 9 Q56 10 62 37"],
    ["M28 10 Q17 12 11 39", "M44 10 Q54 12 50 44"],
];
const sideBands = [
    "M22 10 Q39 18 16 47",
    "M43 9 Q41 26 20 29",
    "M28 10 Q43 24 22 45",
];

function art(number) {
    if (number < 3) return {box: "0 0 72 60", content: frontBands[number].map(band).join("")};
    if (number < 6) {
        const box = number === 4 ? "0 -3 64 52" : "0 0 44 68";
        return {box, content: band(sideBands[number - 3])};
    }
    if (number < 10) {
        const angles = [0, -10, 9, 0];
        return {box: "0 0 100 100", content: `<g transform="rotate(${angles[number - 6]} 50 50)">${front(number === 6 || number === 9)}</g>`};
    }
    if (number === 10) {
        return {box: "-3 -4 52 95", content: `<g transform="rotate(9 26 49)">${profile()}</g>`};
    }
    if (number === 13) {
        return {
            box: "-9 -10 118 108",
            content: `${fill("M-3 88 Q10 84 20 85 L39 80 Q56 78 68 81 L95 81 L98 84 L105 84 L100 88 L91 90 L100 91 L79 94 L66 93 Q43 96 19 93 L7 94 L11 92 L-3 92 L4 90 Z", "#342724", 0.39)}
                ${line("M-2 94 L12 94 M20 95 L29 94 M62 95 L69 95 M87 93 L96 92", "#342724", 0.85, 'opacity=".4"')}
                <g transform="rotate(-8 50 55)">${front()}</g>`,
        };
    }
    throw new Error(`Unexpected backpack frame: ${number}`);
}

async function render(frame, output) {
    const {box, content} = art(frame.frameNum);
    const svg = Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg"
        width="${frame.width * 3}" height="${frame.height * 3}" viewBox="${box}"
        stroke-linejoin="round" stroke-linecap="round">${defs}${content}</svg>`);
    await sharp(svg).resize(frame.width, frame.height).png()
        .toFile(path.join(output, `swap_body-${frame.frameNum}.png`));
}

const [output] = process.argv.slice(2);
const frames = JSON.parse(fs.readFileSync(0, "utf8"));
Promise.all(frames.map(frame => render(frame, output)))
    .then(() => require("./painted.cjs")(output, frames)).catch(error => {
    console.error(error);
    process.exitCode = 1;
});
