
const sharp = require('sharp');
const fs = require('fs');

async function extractLeaves() {
  const cardPath = 'C:/Users/aryan/.gemini/antigravity-ide/brain/8bc2c1e8-6817-41ed-9cd6-7d1cf02620cd/scratch/crop_card.png';
  const raw = await sharp(cardPath).raw().toBuffer({ resolveWithObject: true });
  const { data, info } = raw;
  const { width, height, channels } = info;

  // Let's locate the leaves precisely in crop_card.png
  // 1. Center leaf (above "Your level" / "Sapling"): around X: 570..610, Y: 25..65
  // 2. Leaf to top-right of mascot: around X: 295..335, Y: 20..60
  // 3. Leaf to right of badge / near badge: around X: 715..755, Y: 105..145
  // 4. Leaf to top-left of mascot: around X: 80..120, Y: 30..70

  const leafDefs = [
    { name: 'rewards_floating_leaf_1', x: 570, y: 25, w: 45, h: 45 },
    { name: 'rewards_floating_leaf_2', x: 295, y: 20, w: 45, h: 45 },
    { name: 'rewards_floating_leaf_3', x: 715, y: 105, w: 45, h: 45 },
    { name: 'rewards_floating_leaf_4', x: 80, y: 30, w: 45, h: 45 }
  ];

  for (const def of leafDefs) {
    const leafBuf = Buffer.alloc(def.w * def.h * 4);
    for (let dy = 0; dy < def.h; dy++) {
      for (let dx = 0; dx < def.w; dx++) {
        const srcX = def.x + dx;
        const srcY = def.y + dy;
        const srcIdx = (srcY * width + srcX) * channels;
        const dstIdx = (dy * def.w + dx) * 4;

        const r = data[srcIdx];
        const g = data[srcIdx + 1];
        const b = data[srcIdx + 2];

        // Sky background around these areas:
        // R is ~210..245, G is ~240..255, B is ~235..255
        // Green leaf: G is vibrant, R is significantly lower than in the sky
        // Specifically, in the leaf: G - R > 50, or R < 185
        // Let's compute greenness / color difference from sky
        const skyDist = Math.hypot(r - 225, g - 248, b - 242);
        
        // Leaf indicator:
        // A pixel is definitively leaf if G > R + 25 and R < 200
        let alpha = 0;
        if (g > r + 30 && r < 195) {
          alpha = Math.min(255, Math.max(0, Math.round(((g - r) - 20) * 5)));
        } else if (g > r + 15 && r < 210) {
          alpha = Math.min(255, Math.max(0, Math.round(((g - r) - 15) * 10)));
        }

        if (alpha > 0) {
          leafBuf[dstIdx] = r;
          leafBuf[dstIdx + 1] = g;
          leafBuf[dstIdx + 2] = b;
          leafBuf[dstIdx + 3] = alpha;
        } else {
          leafBuf[dstIdx] = 0;
          leafBuf[dstIdx + 1] = 0;
          leafBuf[dstIdx + 2] = 0;
          leafBuf[dstIdx + 3] = 0;
        }
      }
    }

    const leafImg = await sharp(leafBuf, { raw: { width: def.w, height: def.h, channels: 4 } })
      .trim()
      .png()
      .toBuffer();

    fs.writeFileSync(`F:/Code/Eco Campus/apps/mobile/assets/images/rewards/${def.name}.png`, leafImg);
    console.log(`Saved ${def.name}.png`);
  }
}

extractLeaves().catch(console.error);
