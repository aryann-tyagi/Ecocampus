
const sharp = require('sharp');
const fs = require('fs');

async function createCleanBadge() {
  const badgeCropPath = 'C:/Users/aryan/.gemini/antigravity-ide/brain/8bc2c1e8-6817-41ed-9cd6-7d1cf02620cd/scratch/badge_exact_crop.png';
  const raw = await sharp(badgeCropPath).raw().toBuffer({ resolveWithObject: true });
  const { data, info } = raw;
  const { width, height, channels } = info;

  // Center of badge in badge_exact_crop
  const cx = 80;
  const cy = 75;

  // Let's create an SVG path for a rounded hexagon that matches the outer edge of the badge
  // Vertices of the hexagon:
  // Top: (80, 12)
  // Top-Right: (138, 45)
  // Bottom-Right: (138, 105)
  // Bottom: (80, 138)
  // Bottom-Left: (22, 105)
  // Top-Left: (22, 45)
  
  // We can create a rounded polygon SVG mask
  const svgMask = `
    <svg width="${width}" height="${height}">
      <defs>
        <filter id="blur">
          <feGaussianBlur stdDeviation="0.6"/>
        </filter>
      </defs>
      <!-- Draw rounded polygon using SVG path with arcs or rounded corners -->
      <path d="
        M 76, 12
        Q 80, 10 84, 12
        L 134, 43
        Q 138, 45 138, 50
        L 138, 100
        Q 138, 105 134, 107
        L 84, 138
        Q 80, 140 76, 138
        L 26, 107
        Q 22, 105 22, 100
        L 22, 50
        Q 22, 45 26, 43
        Z
      " fill="white" filter="url(#blur)"/>
    </svg>
  `;

  // Apply mask
  const maskBuffer = Buffer.from(svgMask);
  
  const output = await sharp(badgeCropPath)
    .composite([{ input: maskBuffer, blend: 'dest-in' }])
    .png()
    .toBuffer();

  const outPath = 'C:/Users/aryan/.gemini/antigravity-ide/brain/8bc2c1e8-6817-41ed-9cd6-7d1cf02620cd/scratch/badge_masked.png';
  fs.writeFileSync(outPath, output);
  console.log('Saved badge_masked.png');
}

createCleanBadge().catch(console.error);
