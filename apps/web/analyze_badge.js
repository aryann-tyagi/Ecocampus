
const sharp = require('sharp');
const fs = require('fs');

async function testBadgeMask() {
  const badgeRawPath = 'C:/Users/aryan/.gemini/antigravity-ide/brain/8bc2c1e8-6817-41ed-9cd6-7d1cf02620cd/scratch/badge_raw.png';
  const raw = await sharp(badgeRawPath).raw().toBuffer({ resolveWithObject: true });
  const { data, info } = raw;
  const { width, height, channels } = info;
  console.log(`Badge raw: ${width}x${height}, channels=${channels}`);

  // Find the white border pixels (R>245, G>245, B>245)
  let minX = width, maxX = 0, minY = height, maxY = 0;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const idx = (y * width + x) * channels;
      const r = data[idx];
      const g = data[idx + 1];
      const b = data[idx + 2];
      if (r > 240 && g > 240 && b > 240) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  console.log(`White border bounds: X: ${minX}..${maxX} (w=${maxX - minX + 1}), Y: ${minY}..${maxY} (h=${maxY - minY + 1})`);
  const centerX = (minX + maxX) / 2;
  const centerY = (minY + maxY) / 2;
  console.log(`Center: (${centerX}, ${centerY})`);
}

testBadgeMask().catch(console.error);
