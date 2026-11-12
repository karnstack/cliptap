// Generates the static images in public/ from ../Resources/icon.svg.
// Run with: pnpm run assets
//
// Outputs:
//   public/icon.svg            icon cropped to its rounded square (page + favicon)
//   public/favicon.ico         32×32 PNG inside an ICO wrapper
//   public/apple-touch-icon.png 180×180, full-bleed (iOS adds its own mask)
//   public/og.png              1200×630 Open Graph / Twitter card

import { readFile, writeFile } from "node:fs/promises";
import { createRequire } from "node:module";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { Resvg } from "@resvg/resvg-js";
import satori from "satori";

const require = createRequire(import.meta.url);
const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const pub = (f) => join(root, "public", f);

const source = await readFile(join(root, "..", "Resources", "icon.svg"), "utf8");

// The source icon sits on the macOS icon grid: a 1024 canvas with ~100px of
// transparent margin. Crop to the rounded square so it fills its box on the web.
const cropped = source
  .replace(/<!--.*?-->\n?/s, "")
  .replace('width="1024" height="1024"', 'width="824" height="824"')
  .replace('viewBox="0 0 1024 1024"', 'viewBox="100 100 824 824"');

// Full-bleed variant for apple-touch-icon: square corners, iOS rounds them.
const square = cropped.replace('rx="230"', 'rx="0"');

const png = (svg, width) =>
  new Resvg(svg, { fitTo: { mode: "width", value: width } }).render().asPng();

function ico(pngBuffer, size) {
  const header = Buffer.alloc(6);
  header.writeUInt16LE(0, 0); // reserved
  header.writeUInt16LE(1, 2); // type: icon
  header.writeUInt16LE(1, 4); // image count
  const entry = Buffer.alloc(16);
  entry.writeUInt8(size, 0);
  entry.writeUInt8(size, 1);
  entry.writeUInt8(0, 2); // palette
  entry.writeUInt8(0, 3); // reserved
  entry.writeUInt16LE(1, 4); // color planes
  entry.writeUInt16LE(32, 6); // bits per pixel
  entry.writeUInt32LE(pngBuffer.length, 8);
  entry.writeUInt32LE(6 + 16, 12);
  return Buffer.concat([header, entry, pngBuffer]);
}

await writeFile(pub("icon.svg"), cropped);
await writeFile(pub("favicon.ico"), ico(png(cropped, 32), 32));
await writeFile(pub("apple-touch-icon.png"), png(square, 180));

// Open Graph image ----------------------------------------------------------

const font = (weight) =>
  readFile(require.resolve(`@fontsource/inter/files/inter-latin-${weight}-normal.woff`));
const fonts = [
  { name: "Inter", data: await font(400), weight: 400, style: "normal" },
  { name: "Inter", data: await font(600), weight: 600, style: "normal" },
];
const iconData = `data:image/svg+xml;base64,${Buffer.from(cropped).toString("base64")}`;

// Inter's web subsets have no ⌘ glyph, so draw the symbol as a small SVG.
const commandSvg = (color, stroke) =>
  `data:image/svg+xml;base64,${Buffer.from(
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="${color}" stroke-width="${stroke}" stroke-linecap="round" stroke-linejoin="round"><path d="M15 6v12a3 3 0 1 0 3-3H6a3 3 0 1 0 3 3V6a3 3 0 1 0-3 3h12a3 3 0 1 0-3-3"/></svg>`,
  ).toString("base64")}`;

const h = (type, style, ...children) => ({ type, props: { style, children } });
const img = (src, w, hgt = w, style = {}) => ({
  type: "img",
  props: { src, width: w, height: hgt, style },
});

const keycap = () =>
  h(
    "div",
    {
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      width: 148,
      height: 148,
      borderRadius: 30,
      background: "#ffffff",
      border: "2px solid rgba(0, 40, 35, 0.12)",
      boxShadow: "0 5px 0 rgba(0, 40, 35, 0.12)",
    },
    img(commandSvg("#3d4a48", 1.6), 64),
  );

const og = h(
  "div",
  {
    width: 1200,
    height: 630,
    boxSizing: "border-box",
    display: "flex",
    flexDirection: "column",
    justifyContent: "space-between",
    padding: "92px 104px 80px",
    background: "#fbfcfc",
    fontFamily: "Inter",
    color: "#0f1918",
  },
  h(
    "div",
    { display: "flex", justifyContent: "space-between", alignItems: "flex-end" },
    h(
      "div",
      { display: "flex", flexDirection: "column" },
      img(iconData, 112),
      h("div", { marginTop: 40, fontSize: 68, fontWeight: 600, letterSpacing: -1.5, lineHeight: 1.1 }, "Cliptap"),
      h(
        "div",
        { display: "flex", flexDirection: "column", marginTop: 16, fontSize: 38, lineHeight: 1.35, color: "#52605e" },
        h("div", {}, "Clipboard history for macOS."),
        h(
          "div",
          { display: "flex", alignItems: "center" },
          "Tap",
          img(commandSvg("#52605e", 2.1), 29, 29, { margin: "2px 11px 0 11px" }),
          "twice, pick, paste.",
        ),
      ),
    ),
    h("div", { display: "flex", gap: 20, marginBottom: 6 }, keycap(), keycap()),
  ),
  h(
    "div",
    { display: "flex", justifyContent: "space-between", fontSize: 24, color: "#75817f" },
    h("div", {}, "cliptap.app"),
    h("div", {}, "Free · Open source · macOS 14+"),
  ),
);

const svg = await satori(og, { width: 1200, height: 630, fonts });
await writeFile(pub("og.png"), new Resvg(svg, { fitTo: { mode: "width", value: 1200 } }).render().asPng());

console.log("Wrote icon.svg, favicon.ico, apple-touch-icon.png, og.png to public/");
