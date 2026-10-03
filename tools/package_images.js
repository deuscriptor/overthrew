// Every image the package ships is used (see "Package contents" in tools/README.md). An image counts as used when
// something the game loads names it:
// - Lua, KeyValues (scripts/) and localization (resource/);
// - a Panorama layout, style or script reachable from the HUD manifest, the loading screen or a Lua/KeyValues path;
// - the external references (RERL block) of a compiled material, model or particle;
// - for item and ability icons (resource/flash3/images, panorama/images/items and spellicons), a texture name in
//   Lua or KeyValues ("AbilityTextureName", GetTexture).
// Panorama scripts build some paths at runtime: each ${...} in a template literal stands for one path segment, and
// a folder swap such as .replace("/team_icons/", "/team_icons_hr/") also names the swapped path.
//   node tools/package_images.js   (run by run_tests.js)
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { parse, styleText, layoutStrings, root } = require("./panorama_resources");

const ROOTS = ["panorama/layout/custom_game/custom_ui_manifest.vxml_c", "panorama/layout/custom_game/custom_loading_screen.vxml_c"];

const walk = (dir) => fs.readdirSync(dir, { withFileTypes: true })
	.flatMap(entry => entry.isDirectory() ? walk(path.join(dir, entry.name)) : [path.join(dir, entry.name)]);
const read = (file) => fs.readFileSync(path.join(root, file));

// Asset paths in a text, from a scheme (s2r://, file://{images}/, file://{resources}/, raw://) or a package folder.
const pathStart = /s2r:\/\/|file:\/\/\{(?:images|resources)\}\/|raw:\/\/|(?<![\w/{}.])(?=(?:panorama|particles|models|materials)\/)/g;
function paths(text) {
	// Commented-out code loads nothing.
	text = text.replace(/\/\*[\s\S]*?\*\//g, "").replace(/^\s*(\/\/|--).*$/gm, "");
	const found = [];
	for (const match of text.matchAll(pathStart)) {
		let ref = match[0];
		for (let i = match.index + ref.length; i < text.length;) {
			if (text[i] === "$" && text[i + 1] === "{") {
				for (let depth = 0; i < text.length; i++) {
					if (text[i] === "{") depth++;
					else if (text[i] === "}" && --depth === 0) break;
				}
				ref += "*";
				i++;
			} else if (/[\w\-./{}]/.test(text[i])) ref += text[i++];
			else break;
		}
		found.push(ref.replace(/\.+$/, ""));
	}
	return found;
}
const folderSwaps = (text) => [...text.matchAll(/\.replace\(\s*(["'`])(\/[\w/]+\/)\1\s*,\s*(["'`])(\/[\w/]+\/)\3\s*\)/g)]
	.map(match => [match[2], match[4]]);

// External references of a compiled resource: RERL lists a 16-byte entry per file, whose name sits at a relative offset.
function externalReferences(bytes) {
	if (bytes.length < 16 || bytes.readUInt32LE(0) !== bytes.length) return [];
	const table = 8 + bytes.readUInt32LE(8);
	for (let i = 0; i < bytes.readUInt32LE(12); i++) {
		const entry = table + i * 12;
		if (bytes.toString("ascii", entry, entry + 4) !== "RERL") continue;
		const start = entry + 4 + bytes.readUInt32LE(entry + 4);
		const list = start + bytes.readUInt32LE(start);
		return Array.from({ length: bytes.readUInt32LE(start + 4) }, (_, n) => {
			const name = list + n * 16 + 8;
			const offset = name + bytes.readUInt32LE(name);
			return bytes.toString("utf8", offset, bytes.indexOf(0, offset));
		});
	}
	return [];
}

function verify() {
	const files = ["materials", "models", "panorama", "particles", "resource", "scripts"]
		.flatMap(dir => walk(path.join(root, dir))).map(file => path.relative(root, file).replace(/\\/g, "/"));
	const byLowerCase = new Map(files.map(file => [file.toLowerCase(), file]));
	const resolve = (ref) => {
		const name = ref.toLowerCase().replace(/^s2r:\/\//, "").replace(/^file:\/\/\{images\}\//, "panorama/images/")
			.replace(/^file:\/\/\{resources\}\//, "panorama/").replace(/^raw:\/\//, "");
		// Compiled references drop the _c; source ones name the original image, compiled to <name>_png.vtex_c.
		const forms = [name, name + "_c", name.replace(/\.(png|jpg|psd|tga)$/, "_$1.vtex_c"),
			name.replace(/\.xml$/, ".vxml_c"), name.replace(/\.js$/, ".vjs_c"), name.replace(/\.css$/, ".vcss_c")];
		if (!name.includes("*")) return forms.filter(form => byLowerCase.has(form)).map(form => byLowerCase.get(form));
		const pattern = new RegExp(`^(${forms.map(form => form.split("*").map(part => part.replace(/[.+?^$()|[\]\\{}]/g, "\\$&")).join("[^/]*")).join("|")})$`);
		return files.filter(file => pattern.test(file.toLowerCase()));
	};

	const used = new Set();
	const names = new Set();
	// Lua, KeyValues and localization.
	const scriptTexts = files.filter(file => /^(scripts|resource)\/.*\.(lua|txt)$/.test(file)).map(file => read(file).toString("utf8"));
	for (const text of scriptTexts) {
		for (const ref of paths(text)) resolve(ref).forEach(file => used.add(file));
		for (const [, name] of text.matchAll(/["']([\w/]+)["']/g)) names.add(name.toLowerCase());
	}
	// Panorama files reachable from the manifest, the loading screen and the paths above.
	const panoramaText = (file) => file.endsWith(".vjs_c") ? parse(read(file)).source
		: file.endsWith(".vcss_c") ? styleText(read(file)) : file.endsWith(".vxml_c") ? layoutStrings(read(file)).join("\n") : null;
	const texts = new Map();
	const queue = [...ROOTS, ...used].filter(file => /\.v(js|css|xml)_c$/.test(file));
	for (let file; (file = queue.shift());) {
		if (texts.has(file)) continue;
		texts.set(file, panoramaText(file));
		for (const ref of paths(texts.get(file))) for (const found of resolve(ref)) {
			used.add(found);
			if (/\.v(js|css|xml)_c$/.test(found)) queue.push(found);
		}
	}
	const swaps = [...texts.values()].flatMap(folderSwaps);
	for (const text of texts.values()) for (const ref of paths(text)) for (const [from, to] of swaps)
		if (ref.includes(from)) resolve(ref.replace(from, to)).forEach(file => used.add(file));
	// Compiled materials, models and particles.
	for (const file of files.filter(file => /^(materials|models|particles)\/.*_c$/.test(file)))
		for (const ref of externalReferences(read(file))) resolve(ref).forEach(found => used.add(found));

	const icon = (file) => {
		const match = file.match(/^(?:resource\/flash3\/images\/(items|spellicons)\/(.+)\.png|panorama\/images\/(items|spellicons)\/(.+)_png\.vtex_c)$/);
		if (!match) return false;
		const [kind, name] = match[1] ? [match[1], match[2]] : [match[3], match[4]];
		return names.has(name) || (kind === "items" && names.has(`item_${name}`));
	};
	const images = files.filter(file => /^(panorama|materials|models)\/.*\.vtex_c$|^resource\/flash3\/images\/.*\.png$/.test(file));
	const unused = images.filter(file => !used.has(file) && !icon(file));
	assert.deepEqual(unused, [], "Every shipped image is used by Lua, KeyValues, localization, a loaded Panorama file or a compiled asset");
	console.log(`PASS all ${images.length} shipped images are used; ${texts.size} Panorama files load`);
}

if (require.main === module) verify();
module.exports = { verify, paths };
