// Panorama texture memory (see "Texture memory" in tools/README.md). panorama_textures.json lists every re-encoded
// texture: its size (4/3 of the largest box it is drawn in, so it stays sharp up to 1440p), whether its unused alpha
// is dropped (the compiler then stores DXT5 at a quarter of the RGBA8888 memory) and where it is shown.
//   node tools/panorama_textures.js build   regenerate the listed textures from their originals in git (Windows,
//                                          Workshop Tools); needs the full history, not a shallow clone
//   node tools/panorama_textures.js verify  committed textures match the list, and no uncompressed texture keeps
//                                          an alpha channel it does not use (run by panorama_resources.js verify)
const fs = require("node:fs");
const path = require("node:path");
const zlib = require("node:zlib");
const { spawnSync } = require("node:child_process");

const root = path.resolve(__dirname, "..");
const manifestPath = path.join(__dirname, "panorama_textures.json");
const content = path.resolve(root, "../../../content/dota_addons", path.basename(root));
const resourceCompiler = path.resolve(root, "../../bin/win64/resourcecompiler.exe");

// VTexFormat values, as in ValveResourceFormat.
const FORMAT = { DXT1: 1, DXT5: 2, RGBA8888: 4, PNG_RGBA8888: 16, PNG_DXT5: 18, BGRA8888: 28 };
const FORMAT_NAME = Object.fromEntries(Object.entries(FORMAT).map(([name, id]) => [id, name]));
const UNCOMPRESSED = [FORMAT.RGBA8888, FORMAT.PNG_RGBA8888, FORMAT.BGRA8888];
// Alpha this high everywhere counts as unused: at most 4% see-through, and only on edge pixels.
const OPAQUE_ALPHA = 245;

function parseTexture(bytes) {
	const table = 8 + bytes.readUInt32LE(8);
	for (let i = 0; i < bytes.readUInt32LE(12); i++) {
		const entry = table + i * 12;
		if (bytes.toString("ascii", entry, entry + 4) !== "DATA") continue;
		const data = entry + 4 + bytes.readUInt32LE(entry + 4);
		if (bytes.readUInt16LE(data) !== 1) throw new Error("Unsupported texture version");
		return {
			width: bytes.readUInt16LE(data + 20),
			height: bytes.readUInt16LE(data + 22),
			format: bytes[data + 26],
			mips: bytes[data + 27],
			// Pixel data follows the resource blocks.
			pixels: bytes.subarray(data + bytes.readUInt32LE(entry + 8)),
		};
	}
	throw new Error("Missing DATA block");
}

const ADAM7 = [[0, 0, 8, 8], [4, 0, 8, 8], [0, 4, 4, 8], [2, 0, 4, 4], [0, 2, 2, 4], [1, 0, 2, 2], [0, 1, 1, 2]];

// PNG to 8-bit RGBA. `stopBelowAlpha` ends early at the first pixel with less alpha and returns null.
function decodePng(buf, stopBelowAlpha = -1) {
	let pos = 8, width, height, depth, type, interlace, palette, trns;
	const idat = [];
	while (pos < buf.length) {
		const length = buf.readUInt32BE(pos), kind = buf.toString("ascii", pos + 4, pos + 8);
		const chunk = buf.subarray(pos + 8, pos + 8 + length);
		if (kind === "IHDR") [width, height, depth, type, interlace] = [chunk.readUInt32BE(0), chunk.readUInt32BE(4), chunk[8], chunk[9], chunk[12]];
		else if (kind === "PLTE") palette = chunk;
		else if (kind === "tRNS") trns = chunk;
		else if (kind === "IDAT") idat.push(chunk);
		else if (kind === "IEND") break;
		pos += 12 + length;
	}
	const channels = { 0: 1, 2: 3, 3: 1, 4: 2, 6: 4 }[type];
	const bpp = Math.max(1, (channels * depth) >> 3);
	const max = (1 << depth) - 1;
	const raw = zlib.inflateSync(Buffer.concat(idat));
	const rgba = Buffer.alloc(width * height * 4);
	let offset = 0;
	for (const [x0, y0, dx, dy] of interlace ? ADAM7 : [[0, 0, 1, 1]]) {
		const pw = Math.ceil((width - x0) / dx), ph = Math.ceil((height - y0) / dy);
		if (pw <= 0 || ph <= 0) continue;
		const stride = Math.ceil((pw * channels * depth) / 8);
		let prev = Buffer.alloc(stride);
		for (let y = 0; y < ph; y++) {
			const filter = raw[offset];
			const line = Buffer.from(raw.subarray(offset + 1, offset + 1 + stride));
			offset += 1 + stride;
			for (let i = 0; i < stride; i++) {
				const a = i >= bpp ? line[i - bpp] : 0, b = prev[i], c = i >= bpp ? prev[i - bpp] : 0;
				if (filter === 1) line[i] += a;
				else if (filter === 2) line[i] += b;
				else if (filter === 3) line[i] += (a + b) >> 1;
				else if (filter === 4) {
					const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
					line[i] += pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
				}
			}
			prev = line;
			const sample = (index) => depth === 8 ? line[index] : depth === 16 ? line[index * 2]
				: Math.round((((line[(index * depth) >> 3] >> (8 - depth - ((index * depth) & 7))) & max) * 255) / max);
			for (let x = 0; x < pw; x++) {
				const o = ((y0 + y * dy) * width + x0 + x * dx) * 4;
				if (type === 6) for (let k = 0; k < 4; k++) rgba[o + k] = sample(x * 4 + k);
				else if (type === 2) for (let k = 0; k < 4; k++) rgba[o + k] = k < 3 ? sample(x * 3 + k) : 255;
				else if (type === 4 || type === 0) {
					rgba.fill(sample(x * (type === 4 ? 2 : 1)), o, o + 3);
					rgba[o + 3] = type === 4 ? sample(x * 2 + 1) : 255;
				} else {
					const index = depth === 8 ? line[x] : (line[(x * depth) >> 3] >> (8 - depth - ((x * depth) & 7))) & max;
					palette.copy(rgba, o, index * 3, index * 3 + 3);
					rgba[o + 3] = trns && index < trns.length ? trns[index] : 255;
				}
				if (rgba[o + 3] < stopBelowAlpha) return null;
			}
		}
	}
	return { width, height, rgba };
}

function decodeDxt(pixels, width, height, format) {
	const rgba = Buffer.alloc(width * height * 4);
	const color = (v) => [((v >> 11) & 31) * 255 / 31, ((v >> 5) & 63) * 255 / 63, (v & 31) * 255 / 31];
	let offset = 0;
	for (let by = 0; by < height; by += 4) {
		for (let bx = 0; bx < width; bx += 4) {
			const alpha = new Array(16).fill(255);
			if (format === FORMAT.DXT5) {
				const a0 = pixels[offset], a1 = pixels[offset + 1];
				const table = [a0, a1];
				for (let i = 1; i < (a0 > a1 ? 7 : 5); i++) table.push(a0 > a1 ? ((7 - i) * a0 + i * a1) / 7 : ((5 - i) * a0 + i * a1) / 5);
				if (a0 <= a1) table.push(0, 255);
				const bits = pixels.readUIntLE(offset + 2, 6);
				for (let i = 0; i < 16; i++) alpha[i] = table[Math.floor(bits / 2 ** (3 * i)) & 7];
				offset += 8;
			}
			const c0 = pixels.readUInt16LE(offset), c1 = pixels.readUInt16LE(offset + 2), bits = pixels.readUInt32LE(offset + 4);
			const p0 = color(c0), p1 = color(c1);
			const four = format === FORMAT.DXT5 || c0 > c1;
			const palette = [p0, p1, p0.map((v, k) => four ? (2 * v + p1[k]) / 3 : (v + p1[k]) / 2), p0.map((v, k) => four ? (v + 2 * p1[k]) / 3 : 0)];
			offset += 8;
			for (let i = 0; i < 16; i++) {
				const x = bx + (i & 3), y = by + (i >> 2);
				if (x >= width || y >= height) continue;
				const index = (bits >>> (2 * i)) & 3, o = (y * width + x) * 4;
				for (let k = 0; k < 3; k++) rgba[o + k] = Math.round(palette[index][k]);
				rgba[o + 3] = !four && index === 3 ? 0 : Math.round(alpha[i]);
			}
		}
	}
	return rgba;
}

function decodeTexture(bytes) {
	const texture = parseTexture(bytes);
	const { width, height, format, pixels } = texture;
	if (format === FORMAT.PNG_RGBA8888 || format === FORMAT.PNG_DXT5) return decodePng(pixels);
	if (texture.mips !== 1) throw new Error("Only single-mip raw textures are supported");
	const rgba = Buffer.alloc(width * height * 4);
	if (format === FORMAT.RGBA8888) pixels.copy(rgba, 0, 0, rgba.length);
	else if (format === FORMAT.BGRA8888) for (let i = 0; i < rgba.length; i += 4) rgba.set([pixels[i + 2], pixels[i + 1], pixels[i], pixels[i + 3]], i);
	else if (format === FORMAT.DXT1 || format === FORMAT.DXT5) {
		const decoded = decodeDxt(pixels, width, height, format);
		// Opaque DXT5 art is compiled as scaled YCoCg (Co, Cg, scale, Y), which the compile metadata records as a
		// "YCoCg Conversion" special dependency; ValveResourceFormat decodes it the same way.
		if (format === FORMAT.DXT5 && bytes.subarray(0, bytes.length - pixels.length).includes("YCoCg Conv")) {
			for (let i = 0; i < decoded.length; i += 4) {
				const scale = (decoded[i + 2] >> 3) + 1, co = (decoded[i] - 128) / scale, cg = (decoded[i + 1] - 128) / scale, y = decoded[i + 3];
				decoded.set([y + co - cg, y + cg, y - co - cg].map((v) => Math.max(0, Math.min(255, Math.round(v)))), i);
				decoded[i + 3] = 255;
			}
		}
		return { width, height, rgba: decoded };
	} else throw new Error(`Unsupported format ${FORMAT_NAME[format] || format}`);
	return { width, height, rgba };
}

function minAlpha(image) {
	let min = 255;
	for (let i = 3; i < image.rgba.length; i += 4) min = Math.min(min, image.rgba[i]);
	return min;
}

// Area-average downscale in linear light, weighting colour by alpha so transparent pixels leave no dark fringe.
const toLinear = Float64Array.from({ length: 256 }, (_, v) => ((v /= 255) <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4));
const toSrgb = (v) => Math.round(255 * (v <= 0.0031308 ? 12.92 * v : 1.055 * v ** (1 / 2.4) - 0.055));
function resize(image, width, height) {
	if (image.width === width && image.height === height) return image;
	if (width > image.width || height > image.height) throw new Error("Textures are only ever downscaled");
	const rgba = Buffer.alloc(width * height * 4);
	const sx = image.width / width, sy = image.height / height;
	for (let y = 0; y < height; y++) {
		const y0 = y * sy, y1 = y0 + sy;
		for (let x = 0; x < width; x++) {
			const x0 = x * sx, x1 = x0 + sx;
			const sum = [0, 0, 0], plain = [0, 0, 0];
			let alpha = 0, area = 0;
			// The clamps keep float rounding at the far edges inside the source.
			for (let yy = Math.floor(y0); yy < Math.min(Math.ceil(y1), image.height); yy++) {
				const wy = Math.min(yy + 1, y1) - Math.max(yy, y0);
				for (let xx = Math.floor(x0); xx < Math.min(Math.ceil(x1), image.width); xx++) {
					const w = wy * (Math.min(xx + 1, x1) - Math.max(xx, x0)), i = (yy * image.width + xx) * 4;
					const a = (image.rgba[i + 3] / 255) * w;
					for (let k = 0; k < 3; k++) {
						sum[k] += toLinear[image.rgba[i + k]] * a;
						plain[k] += toLinear[image.rgba[i + k]] * w;
					}
					alpha += a;
					area += w;
				}
			}
			const o = (y * width + x) * 4;
			// Fully transparent areas keep their average colour, as the compiler's colour dilation expects.
			for (let k = 0; k < 3; k++) rgba[o + k] = toSrgb(alpha > 0 ? sum[k] / alpha : plain[k] / area);
			rgba[o + 3] = Math.round((alpha / area) * 255);
		}
	}
	return { width, height, rgba };
}

function crc32(bytes) {
	let crc = 0xffffffff;
	for (const byte of bytes) {
		crc ^= byte;
		for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
	}
	return (crc ^ 0xffffffff) >>> 0;
}

function encodePng(image, alpha) {
	const channels = alpha ? 4 : 3, stride = image.width * channels;
	const rows = [];
	let prev = Buffer.alloc(stride);
	for (let y = 0; y < image.height; y++) {
		const line = Buffer.alloc(stride);
		for (let x = 0; x < image.width; x++) image.rgba.copy(line, x * channels, (y * image.width + x) * 4, (y * image.width + x) * 4 + channels);
		// Adaptive filtering: the filter with the smallest sum of absolute residuals, as libpng does.
		let best;
		for (let filter = 0; filter < 5; filter++) {
			const out = Buffer.alloc(stride + 1);
			out[0] = filter;
			let cost = 0;
			for (let i = 0; i < stride; i++) {
				const a = i >= channels ? line[i - channels] : 0, b = prev[i], c = i >= channels ? prev[i - channels] : 0;
				const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
				const predictor = [0, a, b, (a + b) >> 1, pa <= pb && pa <= pc ? a : pb <= pc ? b : c][filter];
				out[i + 1] = (line[i] - predictor) & 255;
				cost += out[i + 1] < 128 ? out[i + 1] : 256 - out[i + 1];
			}
			if (!best || cost < best.cost) best = { out, cost };
		}
		rows.push(best.out);
		prev = line;
	}
	const chunk = (kind, data) => {
		const head = Buffer.alloc(8);
		head.writeUInt32BE(data.length, 0);
		head.write(kind, 4, "ascii");
		const crc = Buffer.alloc(4);
		crc.writeUInt32BE(crc32(Buffer.concat([head.subarray(4), data])));
		return Buffer.concat([head, data, crc]);
	};
	const header = Buffer.alloc(13);
	header.writeUInt32BE(image.width, 0);
	header.writeUInt32BE(image.height, 4);
	header.set([8, alpha ? 6 : 2, 0, 0, 0], 8);
	return Buffer.concat([
		Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
		chunk("IHDR", header),
		chunk("IDAT", zlib.deflateSync(Buffer.concat(rows), { level: 9 })),
		chunk("IEND", Buffer.alloc(0)),
	]);
}

// panorama/images/x/name_png.vtex_c is compiled from content panorama/images/x/name.png.
const sourceName = (texture) => texture.replace(/_png\.vtex_c$/, ".png");

function files(dir) {
	return fs.readdirSync(dir, { withFileTypes: true }).flatMap((item) => {
		const full = path.join(dir, item.name);
		return item.isDirectory() ? files(full) : [full];
	});
}

// The compiler stores small images raw and larger ones as PNG; the memory format is the same.
const expectedFormats = (entry) => (entry.opaque ? [FORMAT.PNG_DXT5, FORMAT.DXT5] : [FORMAT.PNG_RGBA8888, FORMAT.BGRA8888]);

function checkTexture(name, entry, bytes) {
	const texture = parseTexture(bytes);
	if (!expectedFormats(entry).includes(texture.format))
		throw new Error(`${name}: ${FORMAT_NAME[texture.format]}, expected ${expectedFormats(entry).map((format) => FORMAT_NAME[format]).join(" or ")}`);
	if (texture.width !== entry.size[0] || texture.height !== entry.size[1])
		throw new Error(`${name}: ${texture.width}x${texture.height}, expected ${entry.size.join("x")}`);
}

function build(manifest) {
	const names = Object.keys(manifest.textures);
	const images = [];
	for (const name of names) {
		const entry = manifest.textures[name];
		if (!name.endsWith("_png.vtex_c")) throw new Error(`${name}: only textures compiled from PNG can be rebuilt`);
		const original = spawnSync("git", ["show", `${manifest.originals}:${name}`], { cwd: root, maxBuffer: 1 << 28 });
		if (original.status !== 0) throw new Error(`${name}: no original at ${manifest.originals}: ${original.stderr}`);
		const image = resize(decodeTexture(original.stdout), ...entry.size);
		if (entry.opaque && minAlpha(image) < OPAQUE_ALPHA) throw new Error(`${name}: alpha is used, it cannot be dropped`);
		const source = path.join(content, sourceName(name));
		fs.mkdirSync(path.dirname(source), { recursive: true });
		fs.writeFileSync(source, encodePng(image, !entry.opaque));
		images.push(source);
	}
	// The Panorama compiler builds images that a stylesheet references; this one exists only for that.
	const style = path.join(content, "panorama/layout/custom_game/texture_build.css");
	fs.writeFileSync(style, names.map((name, i) => `.T${i} { background-image: url("file://{images}/${sourceName(name).replace(/^panorama\/images\//, "")}"); }`).join("\n"));
	const result = spawnSync(resourceCompiler, ["-nop4", "-f", "-i", style], { encoding: "utf8", maxBuffer: 1 << 26 });
	for (const file of [style, ...images]) fs.rmSync(file);
	const imagesRoot = path.join(content, "panorama/images");
	for (const folder of new Set(images.map((file) => path.dirname(file))))
		for (let dir = folder; dir.startsWith(imagesRoot) && fs.existsSync(dir) && !fs.readdirSync(dir).length; dir = path.dirname(dir)) fs.rmdirSync(dir);
	fs.rmSync(path.join(root, "panorama/layout/custom_game/texture_build.vcss_c"), { force: true });
	if (result.error || !new RegExp(`OK: ${names.length + 1} compiled, 0 failed`).test(result.stdout || ""))
		throw new Error(`resourcecompiler failed:\n${result.stdout || result.error}`);
	for (const name of names) checkTexture(name, manifest.textures[name], fs.readFileSync(path.join(root, name)));
	console.log(`build: ${names.length} Panorama textures re-encoded from ${manifest.originals}`);
}

function verify(manifest) {
	for (const [name, entry] of Object.entries(manifest.textures)) checkTexture(name, entry, fs.readFileSync(path.join(root, name)));
	let checked = 0;
	for (const file of files(path.join(root, "panorama")).filter((file) => file.endsWith(".vtex_c"))) {
		const bytes = fs.readFileSync(file);
		const texture = parseTexture(bytes);
		if (!UNCOMPRESSED.includes(texture.format)) continue;
		const image = texture.format === FORMAT.PNG_RGBA8888 ? decodePng(texture.pixels, OPAQUE_ALPHA) : decodeTexture(bytes);
		if (image && minAlpha(image) >= OPAQUE_ALPHA)
			throw new Error(`${path.relative(root, file)}: alpha is unused but the texture is stored uncompressed; list it as opaque`);
		checked++;
	}
	console.log(`verify: ${Object.keys(manifest.textures).length} re-encoded Panorama textures match; ${checked} uncompressed textures use their alpha`);
}

const readManifest = () => JSON.parse(fs.readFileSync(manifestPath, "utf8"));

function main() {
	const manifest = readManifest();
	const command = process.argv[2];
	if (command === "build") build(manifest);
	else if (command === "verify") verify(manifest);
	else throw new Error("Usage: node panorama_textures.js build | verify");
}

if (require.main === module) main();
module.exports = { parseTexture, decodePng, decodeDxt, decodeTexture, resize, encodePng, minAlpha, verify: () => verify(readManifest()), OPAQUE_ALPHA, FORMAT };
