const assert = require("node:assert/strict");
const fs = require("node:fs/promises");
const path = require("node:path");
const sharp = require("sharp");

async function bounds(image) {
    const {data, info} = await sharp(image).ensureAlpha().raw().toBuffer({resolveWithObject: true});
    let left = info.width, top = info.height, right = 0, bottom = 0;
    for (let y = 0; y < info.height; y++) {
        for (let x = 0; x < info.width; x++) {
            if (data[(y * info.width + x) * 4 + 3] > 16) {
                left = Math.min(left, x);
                top = Math.min(top, y);
                right = Math.max(right, x + 1);
                bottom = Math.max(bottom, y + 1);
            }
        }
    }
    assert(right > left && bottom > top, "Painted frame must contain visible pixels");
    return {left, top, width: right - left, height: bottom - top};
}

module.exports = async function ApplyPaintedArtwork(output, frames) {
    const master = path.join(__dirname, "painted-master.png");
    const meta = await sharp(master).metadata();
    assert(meta.hasAlpha && meta.width % 3 === 0, "Expected three transparent sprite cells");
    const cellWidth = meta.width / 3;
    const cells = await Promise.all([0, 1].map(async i => {
        const cell = await sharp(master).extract({
            left: i * cellWidth, top: 0, width: cellWidth, height: meta.height,
        }).png().toBuffer();
        const area = await bounds(cell);
        assert(area.left > 0 && area.top > 0 &&
            area.left + area.width < cellWidth && area.top + area.height < meta.height,
        "Sprite must stay inside its own cell");
        return sharp(cell).extract(area).png().toBuffer();
    }));
    const groundMaster = await fs.readFile(path.join(__dirname, "ground-master.png"));
    const ground = await sharp(groundMaster).extract(await bounds(groundMaster)).png().toBuffer();
    const replacements = await Promise.all(frames.filter(f => f.frameNum >= 6).map(async frame => {
        const file = path.join(output, `swap_body-${frame.frameNum}.png`);
        const template = await fs.readFile(file);
        const target = await bounds(template);
        let source = frame.frameNum === 13 ? ground : cells[frame.frameNum === 10 ? 1 : 0];
        const angle = frame.frameNum === 7 ? -10 : frame.frameNum === 8 ? 9 : 0;
        if (angle) {
            source = await sharp(source).rotate(angle, {background: "#00000000"}).png().toBuffer();
            source = await sharp(source).extract(await bounds(source)).png().toBuffer();
        }
        const fitted = await sharp(source).resize(target.width, target.height, {fit: "fill"}).png().toBuffer();
        const png = await sharp({
            create: {width: frame.width, height: frame.height, channels: 4, background: "#00000000"},
        }).composite([{input: fitted, left: target.left, top: target.top}]).png().toBuffer();
        assert.deepEqual(await bounds(png), target, "Texture replacement moved a frame's visible bounds");
        return {file, png};
    }));
    for (const {file, png} of replacements) {
        await fs.writeFile(file, png);
    }
};
