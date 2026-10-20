
const sharp = require('sharp');
const fs = require('fs');

async function refineAssets() {
  // 1. Next level badge
  const badgeMaskedPath = 'C:/Users/aryan/.gemini/antigravity-ide/brain/8bc2c1e8-6817-41ed-9cd6-7d1cf02620cd/scratch/badge_masked.png';
  const badgeOut = 'F:/Code/Eco Campus/apps/mobile/assets/images/rewards/next_level_tree_badge.png';
  await sharp(badgeMaskedPath)
    .trim()
    .png()
    .toFile(badgeOut);
  console.log('Saved refined next_level_tree_badge.png');

  // 2. Refine leaf extraction
  // Let's extract leaf 1 (center leaf) with precision
  const cardPath = 'C:/Users/aryan/.gemini/antigravity-ide/brain/8bc2c1e8-6817-41ed-9cd6-7d1cf02620cd/scratch/crop_card.png';
  const cardRaw = await sharp(cardPath).raw().toBuffer({ resolveWithObject: true });
  const { data, info } = cardRaw;
  const { width, height, channels } = info;

  // Leaf 1: center leaf at x: 575, y: 30, w: 35, h: 35
  async function extractCleanLeaf(cropX, cropY, cropW, cropH, outName) {
    const leafBuf = Buffer.alloc(cropW * cropH * 4);
    for (let dy = 0; dy < cropH; dy++) {
      for (let dx = 0; dx < cropW; dx++) {
        const sx = cropX + dx;
        const sy = cropY + dy;
        const srcIdx = (sy * width + sx) * channels;
        const dstIdx = (dy * cropW + dx) * 4;

        const r = data[srcIdx];
        const g = data[srcIdx + 1];
        const b = data[srcIdx + 2];

        // Green leaf: high G relative to R and B
        // Pure sky in that region is R>200, G>240, B>235 (very whitish cyan)
        // Leaf pixels have: G > 140, G - R > 40, G - B > 40
        const isGreen = (g - r > 35) && (g - b > 35) && (r < 195);
        const isSemiGreen = (g - r > 20) && (g - b > 20) && (r < 210);

        let a = 0;
        if (isGreen) {
          const diff = Math.min(g - r, g - b);
          a = Math.min(255, Math.max(0, Math.round((diff - 20) * 6)));
        } else if (isSemiGreen) {
          const diff = Math.min(g - r, g - b);
          a = Math.min(200, Math.max(0, Math.round((diff - 15) * 5)));
        }

        if (a > 30) {
          leafBuf[dstIdx] = r;
          leafBuf[dstIdx + 1] = g;
          leafBuf[dstIdx + 2] = b;
          leafBuf[dstIdx + 3] = a;
        } else {
          leafBuf[dstIdx] = 0;
          leafBuf[dstIdx + 1] = 0;
          leafBuf[dstIdx + 2] = 0;
          leafBuf[dstIdx + 3] = 0;
        }
      }
    }

    await sharp(leafBuf, { raw: { width: cropW, height: cropH, channels: 4 } })
      .trim()
      .png()
      .toFile(`F:/Code/Eco Campus/apps/mobile/assets/images/rewards/${outName}.png`);
    console.log(`Saved ${outName}.png`);
  }

  await extractCleanLeaf(574, 28, 38, 38, 'rewards_floating_leaf_1');
  await extractCleanLeaf(298, 24, 38, 38, 'rewards_floating_leaf_2');
  await extractCleanLeaf(718, 108, 38, 38, 'rewards_floating_leaf_3');
}

refineAssets().catch(console.error);
