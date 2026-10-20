
const sharp = require('sharp');
const fs = require('fs');

async function createSeamlessCardBg() {
  const cardPath = 'C:/Users/aryan/.gemini/antigravity-ide/brain/8bc2c1e8-6817-41ed-9cd6-7d1cf02620cd/scratch/crop_card.png';
  const cardRaw = await sharp(cardPath).raw().toBuffer({ resolveWithObject: true });
  const { data, info } = cardRaw;
  const { width, height, channels } = info;

  // Mask where 1 = inpaint needed, 0 = keep original pixel
  const mask = new Uint8Array(width * height);

  // Helper to mark a rectangle or circle in mask
  function markRect(x0, y0, w, h) {
    for (let y = y0; y < y0 + h && y < height; y++) {
      for (let x = x0; x < x0 + w && x < width; x++) {
        mask[y * width + x] = 1;
      }
    }
  }

  function markCircle(cx, cy, r) {
    const r2 = r * r;
    for (let y = Math.max(0, cy - r); y <= Math.min(height - 1, cy + r); y++) {
      for (let x = Math.max(0, cx - r); x <= Math.min(width - 1, cx + r); x++) {
        if ((x - cx) * (x - cx) + (y - cy) * (y - cy) <= r2) {
          mask[y * width + x] = 1;
        }
      }
    }
  }

  // 1. Mark leaf 1 (top-left sky): around x: 104, y: 50
  markCircle(104, 50, 18);

  // 2. Mark leaf 2 (top-right of mascot sprout): around x: 315, y: 44
  markCircle(315, 44, 22);

  // 3. Mark leaf 3 (lower-right of mascot): around x: 362, y: 133
  markCircle(362, 133, 18);

  // 4. Mark center area (text, progress bar, subtitle, leaf 4, leaf 5):
  // X: 375 to 740, Y: 18 to 215
  markRect(380, 20, 360, 195);

  // Buffer for working pixels
  const rBuf = new Float32Array(width * height);
  const gBuf = new Float32Array(width * height);
  const bBuf = new Float32Array(width * height);

  for (let i = 0; i < width * height; i++) {
    rBuf[i] = data[i * channels];
    gBuf[i] = data[i * channels + 1];
    bBuf[i] = data[i * channels + 2];
  }

  // Initial fill for center area to match the exact natural landscape:
  // Sky: Y: 0..150. Horizon blend: Y: 150..170. Grass: Y: 170..245
  for (let y = 0; y < height; y++) {
    for (let x = 375; x < 745; x++) {
      const idx = y * width + x;
      if (mask[idx] === 1) {
        if (y < 155) {
          const t = y / 155.0;
          // Sky from cyan #D8F4EA (216, 244, 234) to soft white-mint #EEF8F2 (238, 248, 242)
          rBuf[idx] = 216 * (1 - t) + 238 * t;
          gBuf[idx] = 244 * (1 - t) + 248 * t;
          bBuf[idx] = 234 * (1 - t) + 242 * t;
        } else {
          const t = (y - 155) / (height - 155);
          // Grass from horizon #EAF7ED to lush lawn #D0E7AB
          rBuf[idx] = 234 * (1 - t) + 208 * t;
          gBuf[idx] = 247 * (1 - t) + 231 * t;
          bBuf[idx] = 237 * (1 - t) + 171 * t;
        }
      }
    }
  }

  // Initial fill for small leaf circles by averaging neighboring non-mask pixels
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const idx = y * width + x;
      if (mask[idx] === 1 && (x < 375 || x >= 745)) {
        // Average in radius 25
        let sumR = 0, sumG = 0, sumB = 0, count = 0;
        for (let dy = -25; dy <= 25; dy += 3) {
          for (let dx = -25; dx <= 25; dx += 3) {
            const ny = y + dy;
            const nx = x + dx;
            if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
              const nIdx = ny * width + nx;
              if (mask[nIdx] === 0) {
                sumR += rBuf[nIdx];
                sumG += gBuf[nIdx];
                sumB += bBuf[nIdx];
                count++;
              }
            }
          }
        }
        if (count > 0) {
          rBuf[idx] = sumR / count;
          gBuf[idx] = sumG / count;
          bBuf[idx] = sumB / count;
        }
      }
    }
  }

  // Iterative Poisson/Laplacian diffusion for smooth boundary blending (30 iterations)
  const rNext = new Float32Array(rBuf);
  const gNext = new Float32Array(gBuf);
  const bNext = new Float32Array(bBuf);

  for (let iter = 0; iter < 40; iter++) {
    for (let y = 1; y < height - 1; y++) {
      for (let x = 1; x < width - 1; x++) {
        const idx = y * width + x;
        if (mask[idx] === 1) {
          const up = (y - 1) * width + x;
          const down = (y + 1) * width + x;
          const left = y * width + (x - 1);
          const right = y * width + (x + 1);

          rNext[idx] = (rBuf[up] + rBuf[down] + rBuf[left] + rBuf[right]) * 0.25;
          gNext[idx] = (gBuf[up] + gBuf[down] + gBuf[left] + gBuf[right]) * 0.25;
          bNext[idx] = (bBuf[up] + bBuf[down] + bBuf[left] + bBuf[right]) * 0.25;
        }
      }
    }
    rBuf.set(rNext);
    gBuf.set(gNext);
    bBuf.set(bNext);
  }

  // Write out cleaned pixels
  const outBuf = Buffer.alloc(width * height * 4);
  for (let i = 0; i < width * height; i++) {
    outBuf[i * 4] = Math.round(rBuf[i]);
    outBuf[i * 4 + 1] = Math.round(gBuf[i]);
    outBuf[i * 4 + 2] = Math.round(bBuf[i]);
    outBuf[i * 4 + 3] = 255;
  }

  const outPath = 'F:/Code/Eco Campus/apps/mobile/assets/images/rewards/rewards_card_bg.png';
  await sharp(outBuf, { raw: { width, height, channels: 4 } })
    .png()
    .toFile(outPath);
  console.log('Saved seamless rewards_card_bg.png');
}

createSeamlessCardBg().catch(console.error);
