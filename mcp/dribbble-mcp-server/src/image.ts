import fs from "node:fs";

const MB = 1024 * 1024;

export const LIMITS = {
  web: { image: 10 * MB, video: 20 * MB, minWidth: 1600 },
  api: { image: 8 * MB, sizes: ["400x300", "800x600"] },
  tags: 12
} as const;

export type MediaType = "png" | "jpg" | "gif" | "video" | "unknown";

export interface ImageCheck {
  path: string;
  type: MediaType;
  width?: number;
  height?: number;
  size_mb: number;
  target: "web" | "api";
  ok: boolean;
  problems: string[];
}

/** Reads type and pixel size from the file header, without image libraries. */
export function sniff(buf: Buffer): { type: MediaType; width?: number; height?: number } {
  if (buf.subarray(1, 4).toString() === "PNG") return { type: "png", width: buf.readUInt32BE(16), height: buf.readUInt32BE(20) };
  if (buf.subarray(0, 3).toString() === "GIF") return { type: "gif", width: buf.readUInt16LE(6), height: buf.readUInt16LE(8) };
  if (buf[0] === 0xff && buf[1] === 0xd8) {
    let i = 2;
    while (i + 9 < buf.length) {
      if (buf[i] !== 0xff) { i++; continue; }
      const marker = buf[i + 1];
      // SOF0..SOF15 carry the frame size; C4, C8 and CC are other segments
      if (marker >= 0xc0 && marker <= 0xcf && ![0xc4, 0xc8, 0xcc].includes(marker)) {
        return { type: "jpg", height: buf.readUInt16BE(i + 5), width: buf.readUInt16BE(i + 7) };
      }
      i += 2 + buf.readUInt16BE(i + 2);
    }
    return { type: "jpg" };
  }
  if (buf.subarray(4, 8).toString() === "ftyp") return { type: "video" };
  return { type: "unknown" };
}

export function checkImage(filePath: string, target: "web" | "api"): ImageCheck {
  if (!fs.existsSync(filePath)) throw new Error(`File not found: ${filePath}. Pass an absolute path.`);
  const size = fs.statSync(filePath).size;
  const { type, width, height } = sniff(fs.readFileSync(filePath));
  const problems: string[] = [];
  const mb = (n: number) => `${(n / MB).toFixed(1)} MB`;

  if (type === "unknown") problems.push("Unsupported file type. Dribbble takes PNG, JPG, GIF, MP4 and MOV.");
  else if (type === "video") {
    if (target === "api") problems.push("API v2 does not accept video. Post motion through the web uploader.");
    if (size > LIMITS.web.video) problems.push(`Video is ${mb(size)}, the limit is 20 MB.`);
  } else if (target === "api") {
    if (!(LIMITS.api.sizes as readonly string[]).includes(`${width}x${height}`)) {
      problems.push(`API v2 needs exactly 400x300 or 800x600 pixels, this is ${width}x${height}. Export an 800x600 copy.`);
    }
    if (size > LIMITS.api.image) problems.push(`File is ${mb(size)}, the API limit is 8 MB.`);
  } else {
    if (size > LIMITS.web.image) problems.push(`File is ${mb(size)}, the limit is 10 MB. Export as JPG or reduce size.`);
    if (width && width < LIMITS.web.minWidth) problems.push(`Width is ${width}px, Dribbble recommends at least 1600px.`);
    if (width && height && Math.abs(width / height - 4 / 3) > 0.01) {
      problems.push(`Ratio ${width}x${height} is not 4:3, so the feed thumbnail will be cropped.`);
    }
  }
  return { path: filePath, type, width, height, size_mb: Math.round((size / MB) * 100) / 100, target, ok: problems.length === 0, problems };
}
