// Rebuild the existing Source 2 JavaScript containers from editable DATA sources.
// v4 scripts contain plaintext; v3 scripts prefix it with CRC32 and an image table.
// Format reference: ValveResourceFormat/Resource/ResourceTypes/Panorama.cs.
// Original RED2 metadata and every non-DATA byte are retained in the backups.
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.resolve(__dirname, "../..");
const sources = path.join(__dirname, "panorama_sources");
const backups = path.join(__dirname, "panorama_backups");
// The shop item asks for this texture; only its older Flash PNG was supplied.
const imageAliases = {
	"panorama/images/items/orb_epic_png.vtex_c": "panorama/images/custom_game/upgrades/orb_epic_png.vtex_c",
};

function crc32(bytes) {
	let crc = 0xffffffff;
	for (const byte of bytes) {
		crc ^= byte;
		for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
	}
	return (crc ^ 0xffffffff) >>> 0;
}

function parse(bytes) {
	if (bytes.readUInt32LE(0) !== bytes.length || bytes.readUInt16LE(4) !== 12)
		throw new Error("Invalid resource size or header version");
	const version = bytes.readUInt16LE(6);
	const table = 8 + bytes.readUInt32LE(8);
	const count = bytes.readUInt32LE(12);
	const blocks = [];
	for (let i = 0; i < count; i++) {
		const entry = table + i * 12;
		const type = bytes.toString("ascii", entry, entry + 4);
		const start = entry + 4 + bytes.readUInt32LE(entry + 4);
		const size = bytes.readUInt32LE(entry + 8);
		if (start < table + count * 12 || start + size > bytes.length)
			throw new Error(`Invalid ${type} block bounds`);
		blocks.push({ entry, type, start, size });
	}
	const data = blocks.find(block => block.type === "DATA");
	if (!data) throw new Error("Missing DATA block");
	let textStart = data.start;
	if (version < 4) {
		const images = bytes.readUInt16LE(textStart + 4);
		textStart += 6;
		for (let i = 0; i < images; i++) {
			textStart = bytes.indexOf(0, textStart) + 1 + 4 + (version >= 3 ? 4 : 0);
			if (textStart <= 0 || textStart > data.start + data.size) throw new Error("Invalid image table");
		}
		if (crc32(bytes.subarray(textStart, data.start + data.size)) !== bytes.readUInt32LE(data.start))
			throw new Error("Panorama script CRC32 mismatch");
	}
	return { version, blocks, data, textStart, source: bytes.toString("utf8", textStart, data.start + data.size) };
}

function rebuild(original, source) {
	const info = parse(original);
	new vm.Script(source); // Parse JavaScript before writing a compiled resource.
	const text = Buffer.from(source, "utf8");
	const prefix = Buffer.from(original.subarray(info.data.start, info.textStart));
	if (info.version < 4) prefix.writeUInt32LE(crc32(text), 0);
	const data = Buffer.concat([prefix, text]);
	const delta = data.length - info.data.size;
	const bytes = Buffer.concat([
		original.subarray(0, info.data.start), data,
		original.subarray(info.data.start + info.data.size),
	]);
	bytes.writeUInt32LE(bytes.length, 0);
	for (const block of info.blocks) {
		const start = block.start >= info.data.start + info.data.size ? block.start + delta : block.start;
		bytes.writeUInt32LE(start - block.entry - 4, block.entry + 4);
		bytes.writeUInt32LE(block === info.data ? data.length : block.size, block.entry + 8);
	}
	const checked = parse(bytes);
	if (checked.source !== source) throw new Error("DATA round-trip failed");
	for (let i = 0; i < info.blocks.length; i++) {
		const before = info.blocks[i];
		const after = checked.blocks[i];
		if (before.type !== "DATA" && !original.subarray(before.start, before.start + before.size)
			.equals(bytes.subarray(after.start, after.start + after.size))) throw new Error("Unrelated block changed");
	}
	return bytes;
}

function files(dir) {
	return fs.readdirSync(dir, { withFileTypes: true }).flatMap(item => {
		const full = path.join(dir, item.name);
		return item.isDirectory() ? files(full) : [full];
	});
}

function main() {
	const [command, ...names] = process.argv.slice(2);
	if (command === "extract") {
		for (const name of names) {
			if (!name.startsWith("panorama/") || !name.endsWith(".vjs_c") || name.includes(".."))
				throw new Error(`Invalid script path: ${name}`);
			const original = fs.readFileSync(path.join(root, name));
			const backup = path.join(backups, name);
			if (!fs.existsSync(backup)) {
				fs.mkdirSync(path.dirname(backup), { recursive: true });
				fs.writeFileSync(backup, original);
			}
			const source = path.join(sources, name.replace(/\.vjs_c$/, ".js"));
			if (fs.existsSync(source)) throw new Error(`Refusing to overwrite editable source ${source}`);
			fs.mkdirSync(path.dirname(source), { recursive: true });
			fs.writeFileSync(source, parse(original).source, "utf8");
		}
	} else if (command === "build" || command === "verify") {
		let count = 0;
		for (const source of files(sources).filter(name => name.endsWith(".js"))) {
			const name = path.relative(sources, source).replace(/\.js$/, ".vjs_c");
			const rebuilt = rebuild(fs.readFileSync(path.join(backups, name)), fs.readFileSync(source, "utf8"));
			if (command === "build") fs.writeFileSync(path.join(root, name), rebuilt);
			else if (!rebuilt.equals(fs.readFileSync(path.join(root, name)))) throw new Error(`Resource differs: ${name}`);
			count++;
		}
		for (const [target, original] of Object.entries(imageAliases)) {
			const bytes = fs.readFileSync(path.join(root, original));
			const output = path.join(root, target);
			if (command === "build") {
				fs.mkdirSync(path.dirname(output), { recursive: true });
				fs.writeFileSync(output, bytes);
			} else if (!bytes.equals(fs.readFileSync(output))) throw new Error(`Image alias differs: ${target}`);
		}
		console.log(`${command}: ${count} Panorama scripts; syntax, block bounds, CRC32 and DATA verified`);
		console.log(`${command}: ${Object.keys(imageAliases).length} shop image alias verified`);
	} else throw new Error("Usage: node panorama_resources.js extract <panorama/...vjs_c> | build | verify");
}

if (require.main === module) main();
module.exports = { parse, rebuild, crc32, root, sources, backups };
