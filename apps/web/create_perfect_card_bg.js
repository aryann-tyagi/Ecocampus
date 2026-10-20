
const sharp = require('sharp');
const fs = require('fs');

async function createPerfectCardBg() {
  const cardPath = 'C:/Users/aryan/.gemini/antigravity-ide/brain/8bc2c1e8-6817-41ed-9cd6-7d1cf02620cd/scratch/crop_card.png';
  const cardRaw = await sharp(cardPath).raw().toBuffer({ resolveWithObject: true });
  const { data, info } = cardRaw;
  const { width, height, channels } = info;

  const outBuf = Buffer.from(data);

  function getPixel(x, y) {
    x = Math.max(0, Math.min(width - 1, Math.round(x)));
    y = Math.max(0, Math.min(height - 1, Math.round(y)));
    const idx = (y * width + x) * channels;
    return [data[idx], data[idx + 1], data[idx + 2]];
  }

  function setPixel(x, y, r, g, b) {
    x = Math.max(0, Math.min(width - 1, Math.round(x)));
    y = Math.max(0, Math.min(height - 1, Math.round(y)));
    const idx = (y * width + x) * channels;
    outBuf[idx] = Math.round(r);
    outBuf[idx + 1] = Math.round(g);
    outBuf[idx + 2] = Math.round(b);
  }

  // 1. Inpaint Leaf 1 (top-left sky, x: 80..120, y: 35..65)
  // Background here is smooth sky: sample at x=60 and x=135 at same y
  for (let y = 35; y <= 65; y++) {
    const leftCol = getPixel(65, y);
    const rightCol = getPixel(135, y);
    for (let x = 75; x <= 125; x++) {
      const t = (x - 65) / (135 - 65);
      setPixel(x, y, leftCol[0]*(1-t) + rightCol[0]*t, leftCol[1]*(1-t) + rightCol[1]*t, leftCol[2]*(1-t) + rightCol[2]*t);
    }
  }

  // 2. Inpaint Leaf 2 (top-right of mascot sprout, x: 290..330, y: 30..65)
  // Sample sky at x=280 and x=340
  for (let y = 28; y <= 66; y++) {
    const leftCol = getPixel(280, y);
    const rightCol = getPixel(340, y);
    for (let x = 285; x <= 335; x++) {
      const t = (x - 280) / (340 - 280);
      setPixel(x, y, leftCol[0]*(1-t) + rightCol[0]*t, leftCol[1]*(1-t) + rightCol[1]*t, leftCol[2]*(1-t) + rightCol[2]*t);
    }
  }

  // 3. Inpaint Leaf 3 (lower-right of mascot, x: 335..375, y: 115..155)
  // Sample at x=330 and x=385
  for (let y = 115; y <= 155; y++) {
    const leftCol = getPixel(330, y);
    const rightCol = getPixel(385, y);
    for (let x = 333; x <= 380; x++) {
      const t = (x - 330) / (385 - 330);
      setPixel(x, y, leftCol[0]*(1-t) + rightCol[0]*t, leftCol[1]*(1-t) + rightCol[1]*t, leftCol[2]*(1-t) + rightCol[2]*t);
    }
  }

  // 4. Center Area (x: 355 to 755, y: 10 to 225)
  // Let's sample the exact sky profile from x=755 (which has clean sky)
  // and the mascot edge at x=355
  for (let y = 10; y < 228; y++) {
    // Get colors at left edge (x=355) and right edge (x=755)
    let leftC = getPixel(350, y);
    let rightC = getPixel(755, y);

    for (let x = 355; x < 755; x++) {
      const t = (x - 355) / (755 - 355);
      // Soft horizontal interpolation between left boundary and right boundary
      let r = leftC[0] * (1 - t) + rightC[0] * t;
      let g = leftC[1] * (1 - t) + rightC[1] * t;
      let b = leftC[2] * (1 - t) + rightC[2] * t;

      // In the middle, if y is in the text/bar area, ensure it doesn't pick up dark colors from leftC/rightC:
      if (y >= 80 && y <= 210) {
        // Pure natural landscape profile:
        if (y < 155) {
          // Sky: interpolate vertically from clean sky at y=40 to horizon at y=155
          const skyTop = getPixel(x, 25);
          const u = (y - 25) / (155 - 25);
          r = skyTop[0] * (1 - u) + 236 * u;
          g = skyTop[1] * (1 - u) + 248 * u;
          b = skyTop[2] * (1 - u) + 242 * u;
        } else {
          // Grass hill: interpolate from horizon (y=155) to lawn bottom (y=228)
          const lawnBottom = getPixel(x, 232);
          const u = (y - 155) / (232 - 155);
          r = 236 * (1 - u) + lawnBottom[0] * u;
          g = 248 * (1 - u) + lawnBottom[1] * u;
          b = 242 * (1 - u) + lawnBottom[2] * u;
        }
      }

      setPixel(x, y, r, g, b);
    }
  }

  // Soft 3-pixel box blur over the seams for silky smoothness
  for (let pass = 0; pass < 3; pass++) {
    for (let y = 15; y < 225; y++) {
      for (const seamX of [355, 755]) {
        for (let x = seamX - 4; x <= seamX + 4; x++) {
          let sumR = 0, sumG = 0, sumB = 0, cnt = 0;
          for (let dy = -1; dy <= 1; dy++) {
            for (let dx = -1; dx <= 1; dx++) {
              const c = getPixel(x + dx, y + dy);
              sumR += c[0]; sumG += c[1]; sumB += c[2]; cnt++;
            }
          }
          setPixel(x, y, sumR / cnt, sumG / cnt, sumB / cnt);
        }
      }
    }
  }

  const outPath = 'F:/Code/Eco Campus/apps/mobile/assets/images/rewards/rewards_card_bg.png';
  await sharp(outBuf, { raw: { width, height, channels } })
    .png()
    .toFile(outPath);
  console.log('Saved perfect rewards_card_bg.png');
}

createPerfectCardBg().catch(console.error);
