
const sharp = require('sharp');
const fs = require('fs');

async function findBadgeExact() {
  const originalPath = 'C:/Users/aryan/.gemini/antigravity-ide/brain/8bc2c1e8-6817-41ed-9cd6-7d1cf02620cd/.user_uploaded/media_1792493821838.png';
  const raw = await sharp(originalPath).raw().toBuffer({ resolveWithObject: true });
  const { data, info } = raw;
  const { width, height, channels } = info;

  // Let's inspect the region X: 770..925, Y: 150..305
  // White border: R > 240, G > 240, B > 240
  let minX = 9999, maxX = 0, minY = 9999, maxY = 0;
  for (let y = 150; y < 305; y++) {
    for (let x = 770; x < 925; x++) {
      const idx = (y * width + x) * channels;
      const r = data[idx];
      const g = data[idx + 1];
      const b = data[idx + 2];
      if (r > 242 && g > 242 && b > 242) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  console.log(`Exact badge white border in original: X: ${minX}..${maxX} (w=${maxX - minX + 1}), Y: ${minY}..${maxY} (h=${maxY - minY + 1})`);
  const cx = (minX + maxX) / 2;
  const cy = (minY + maxY) / 2;
  console.log(`Center: (${cx}, ${cy})`);
}

findBadgeExact().catch(console.error);
