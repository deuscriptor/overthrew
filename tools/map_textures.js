// Placeholder water and fog textures for ot3_necropolis_ffa (see "Map textures" in tools/README.md). The map's
// ent_dota_lightinfo entities reference them, but its VPK does not contain them, so they ship as loose files.
// Each holds the uniform value Hammer bakes when nothing is painted, as in Valve's test_basic and the original
// Overthrow maps.
//   node tools/map_textures.js build   compile them with Valve's resourcecompiler (Windows, Workshop Tools)
//   node tools/map_textures.js verify  the shipped textures exist and hold those values (run by run_tests.js)
const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const { parseTexture, decodeTexture, FORMAT } = require("./panorama_textures");

const root = path.resolve(__dirname, "..");
const content = path.resolve(root, "../../../content/dota_addons", path.basename(root));
const resourceCompiler = path.resolve(root, "../../bin/win64/resourcecompiler.exe");

const MAP = "ot3_necropolis_ffa";
// Source RGB, linear. A uniform texture samples the same at any size, so each is a single DXT1 block.
const TEXTURES = {
	water_flow_map: [10, 20, 0],
	fog_flow_map: [10, 20, 0],
	fog_opacity_map: [0, 255, 0],
};
const SIZE = 4;
// DXT1 stores 5:6:5 colour endpoints, so a decoded channel can be a few steps off its source.
const TOLERANCE = 4;

const compiled = (name) => path.join(root, "maps", MAP, `${name}.vtex_c`);

function tga(rgb) {
	const header = Buffer.alloc(18);
	header[2] = 2; // uncompressed true colour
	header.writeUInt16LE(SIZE, 12);
	header.writeUInt16LE(SIZE, 14);
	header[16] = 24;
	const pixel = Buffer.from([rgb[2], rgb[1], rgb[0]]);
	return Buffer.concat([header, ...Array(SIZE * SIZE).fill(pixel)]);
}

// The settings Hammer uses for these maps: linear colour, DXT1, no mipmaps, exempt from texture quality.
const vtex = (name) => `<!-- dmx encoding keyvalues2_noids 1 format vtex 1 -->
"CDmeVtex"
{
	"m_inputTextureArray" "element_array"
	[
		"CDmeInputTexture"
		{
			"m_name" "string" "0"
			"m_fileName" "string" "maps/${MAP}/${name}.tga"
			"m_colorSpace" "string" "linear"
			"m_typeString" "string" "2D"
		}
	]
	"m_outputTypeString" "string" "2D"
	"m_outputFormat" "string" "DXT1"
	"m_textureOutputChannelArray" "element_array"
	[
		"CDmeTextureOutputChannel"
		{
			"m_inputTextureArray" "string_array" [ "0" ]
			"m_srcChannels" "string" "rgba"
			"m_dstChannels" "string" "rgba"
			"m_mipAlgorithm" "CDmeImageProcessor"
			{
				"m_algorithm" "string" "None"
				"m_stringArg" "string" ""
				"m_vFloat4Arg" "vector4" "0 0 0 0"
			}
			"m_outputColorSpace" "string" "linear"
		}
	]
	"m_bNoLod" "bool" "1"
}
`;

function check(name) {
	const file = compiled(name);
	if (!fs.existsSync(file)) throw new Error(`${path.relative(root, file)} is missing`);
	const bytes = fs.readFileSync(file);
	const texture = parseTexture(bytes);
	if (texture.format !== FORMAT.DXT1 || texture.mips !== 1) throw new Error(`${name}: expected single-mip DXT1`);
	const { rgba } = decodeTexture(bytes);
	for (let i = 0; i < rgba.length; i += 4)
		if (TEXTURES[name].some((value, k) => Math.abs(rgba[i + k] - value) > TOLERANCE))
			throw new Error(`${name}: pixel ${[...rgba.subarray(i, i + 3)]}, expected ${TEXTURES[name]}`);
}

function build() {
	const folder = path.join(content, "maps", MAP);
	fs.mkdirSync(folder, { recursive: true });
	const sources = [];
	for (const [name, rgb] of Object.entries(TEXTURES)) {
		fs.writeFileSync(path.join(folder, `${name}.tga`), tga(rgb));
		fs.writeFileSync(path.join(folder, `${name}.vtex`), vtex(name));
		sources.push(path.join(folder, `${name}.tga`), path.join(folder, `${name}.vtex`));
	}
	const names = Object.keys(TEXTURES);
	const result = spawnSync(resourceCompiler, ["-nop4", "-f", ...names.flatMap((name) => ["-i", path.join(folder, `${name}.vtex`)])],
		{ encoding: "utf8", maxBuffer: 1 << 26 });
	for (const file of sources) fs.rmSync(file);
	if (!fs.readdirSync(folder).length) fs.rmdirSync(folder);
	if (result.error || !new RegExp(`OK: ${names.length} compiled, 0 failed`).test(result.stdout || ""))
		throw new Error(`resourcecompiler failed:\n${result.stdout || result.error}`);
	names.forEach(check);
	console.log(`build: ${names.length} ${MAP} water and fog textures compiled`);
}

function verify() {
	Object.keys(TEXTURES).forEach(check);
	console.log(`PASS ${MAP} ships its water flow, fog flow and fog opacity textures with neutral values`);
}

if (require.main === module) {
	const command = process.argv[2];
	if (command === "build") build();
	else if (command === "verify") verify();
	else throw new Error("Usage: node map_textures.js build | verify");
}
module.exports = { verify };
