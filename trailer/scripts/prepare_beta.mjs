// Reuse the creator's landing-page media; leave the site itself unchanged.
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import QRCode from "qrcode";
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const site = path.resolve(root, "../../regun-landing-page/dist");
const html = await fs.readFile(path.join(site, "index.html"), "utf8");
const url = html.match(/rel="canonical" href="([^"]+)"/)[1];
const icons = [
  ...html.matchAll(
    /<svg viewBox="([^"]+)" aria-hidden="true">([\s\S]*?)<\/svg>/g,
  ),
];
for (const [i, name] of ["apple", "android"].entries()) {
  await fs.writeFile(
    path.join(root, "public", `${name}.svg`),
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${icons[i][1]}" color="${i === 0 ? "#161b18" : "#ebe6d9"}">${icons[i][2]}</svg>`,
  );
}
await fs.copyFile(
  path.join(site, "assets/gameplay.mp4"),
  path.join(root, "public/beta-gameplay.mp4"),
);
await QRCode.toFile(path.join(root, "public/beta-qr.png"), url, {
  errorCorrectionLevel: "M",
  margin: 4,
  width: 360,
  color: { dark: "#161b18", light: "#ebe6d9" },
});
await fs.writeFile(
  path.join(root, "public/beta-source.json"),
  JSON.stringify(
    {
      url,
      footage: "regun-landing-page/dist/assets/gameplay.mp4",
      ios: html.match(/href="(https:\/\/testflight[^\"]+)"/)[1],
      android: html.match(/href="(https:\/\/appdistribution[^\"]+)"/)[1],
    },
    null,
    2,
  ),
);
console.log("Prepared beta video, platform marks, and QR for", url);
