
const sharp = require('sharp');
const fs = require('fs');

async function createCardBg() {
  const cardPath = 'C:/Users/aryan/.gemini/antigravity-ide/brain/8bc2c1e8-6817-41ed-9cd6-7d1cf02620cd/scratch/crop_card.png';
  const cardRaw = await sharp(cardPath).raw().toBuffer({ resolveWithObject: true });
  const { data, info } = cardRaw;
  const { width, height, channels } = info;

  const bgBuf = Buffer.from(data);

  function getPixel(x, y) {
    x = Math.max(0, Math.min(width - 1, Math.round(x)));
    y = Math.max(0, Math.min(height - 1, Math.round(y)));
    const idx = (y * width + x) * channels;
    return [bgBuf[idx], bgBuf[idx + 1], bgBuf[idx + 2]];
  }

  function setPixel(x, y, r, g, b) {
    x = Math.max(0, Math.min(width - 1, Math.round(x)));
    y = Math.max(0, Math.min(height - 1, Math.round(y)));
    const idx = (y * width + x) * channels;
    bgBuf[idx] = Math.round(r);
    bgBuf[idx + 1] = Math.round(g);
    bgBuf[idx + 2] = Math.round(b);
  }

  // 1. Inpaint Leaf 1 (top-left of mascot sky, x: 80..120, y: 30..70)
  for (let y = 30; y < 75; y++) {
    for (let x = 80; x < 125; x++) {
      // interpolate from sky to the left (x=70) and sky to the right (x=135)
      const leftCol = getPixel(70, y);
      const rightCol = getPixel(135, y);
      const t = (x - 70) / (135 - 70);
      setPixel(x, y, leftCol[0]*(1-t) + rightCol[0]*t, leftCol[1]*(1-t) + rightCol[1]*t, leftCol[2]*(1-t) + rightCol[2]*t);
    }
  }

  // 2. Inpaint Leaf 2 (top-right of mascot, x: 290..335, y: 20..65)
  for (let y = 20; y < 65; y++) {
    for (let x = 290; x < 335; x++) {
      const topCol = getPixel(x, 15);
      const bottomCol = getPixel(x, 70);
      const t = (y - 15) / (70 - 15);
      setPixel(x, y, topCol[0]*(1-t) + bottomCol[0]*t, topCol[1]*(1-t) + bottomCol[1]*t, topCol[2]*(1-t) + bottomCol[2]*t);
    }
  }

  // 3. Inpaint Leaf 3 (lower-right of mascot, x: 340..385, y: 110..155)
  for (let y = 110; y < 155; y++) {
    for (let x = 340; x < 385; x++) {
      const topCol = getPixel(x, 105);
      const bottomCol = getPixel(x, 160);
      const t = (y - 105) / (160 - 105);
      setPixel(x, y, topCol[0]*(1-t) + bottomCol[0]*t, topCol[1]*(1-t) + bottomCol[1]*t, topCol[2]*(1-t) + bottomCol[2]*t);
    }
  }

  // 4. Inpaint Center area (X: 360..735, Y: 10..225)
  // This covers:
  // - "Your level", "Sapling", "120 EcoPoints" (Y: 30..130)
  // - Progress bar (Y: 135..165)
  // - "Next: Tree • Level 4..." (Y: 170..200)
  // - Center leaf 4 (x: 565..615, y: 20..65)
  // - Far right leaf 5 (x: 710..755, y: 100..145)
  // The center scenery is:
  // Sky from Y=0 to Y=150: vertical gradient with gentle cloud curvature
  // Horizon/hill from Y=150 to Y=245: gentle grassy slope
  for (let x = 360; x <= 745; x++) {
    // Sky column: top is y=10 (sample at x), bottom of sky is y=150
    // Let's sample sky profile at x=750 or smooth interpolation
    for (let y = 10; y < 155; y++) {
      // Sky gradient: at y=10: #DAF5EC, at y=80: #E6F7F0, at y=150: #EDF8F2
      const t = (y - 10) / (155 - 10);
      // Soft slight cloud brightness near center-right (x ~ 650)
      const cloudFactor = Math.exp(-Math.pow((x - 650) / 100, 2)) * Math.exp(-Math.pow((y - 110) / 45, 2)) * 8;
      const r = Math.min(255, (218 * (1 - t) + 242 * t) + cloudFactor);
      const g = Math.min(255, (246 * (1 - t) + 250 * t) + cloudFactor);
      const b = Math.min(255, (238 * (1 - t) + 245 * t) + cloudFactor);
      setPixel(x, y, r, g, b);
    }

    // Grass / hill: from y=155 to y=235
    for (let y = 155; y < 235; y++) {
      const t = (y - 155) / (235 - 155);
      // At y=155: #EDF8F2 (horizon blend)
      // At y=190: #F1F9EE (light grassy hill)
      // At y=235: #CFE6A7 (richer foreground lawn)
      let r, g, b;
      if (t < 0.35) {
        const u = t / 0.35;
        r = 237 * (1 - u) + 241 * u;
        g = 248 * (1 - u) + 249 * u;
        b = 242 * (1 - u) + 238 * u;
      } else {
        const u = (t - 0.35) / 0.65;
        r = 241 * (1 - u) + 207 * u;
        g = 249 * (1 - u) + 230 * u;
        b = 238 * (1 - u) + 167 * u;
      }
      setPixel(x, y, r, g, b);
    }
  }

  // Smooth blending on left seam (x: 350..375)
  for (let y = 10; y < 235; y++) {
    for (let x = 350; x < 375; x++) {
      const t = (x - 350) / 25.0;
      const orig = getPixel(350, y);
      const curr = getPixel(x, y);
      setPixel(x, y, orig[0]*(1-t) + curr[0]*t, orig[1]*(1-t) + curr[1]*t, orig[2]*(1-t) + curr[2]*t);
    }
  }

  // Smooth blending on right seam (x: 730..755)
  for (let y = 10; y < 235; y++) {
    for (let x = 730; x < 755; x++) {
      const t = (x - 730) / 25.0;
      const curr = getPixel(x, y);
      const orig = getPixel(755, y);
      setPixel(x, y, curr[0]*(1-t) + orig[0]*t, curr[1]*(1-t) + orig[1]*t, curr[2]*(1-t) + orig[2]*t);
    }
  }

  // Save card background
  const outPath = 'F:/Code/Eco Campus/apps/mobile/assets/images/rewards/rewards_card_bg.png';
  await sharp(bgBuf, { raw: { width, height, channels } })
    .png()
    .toFile(outPath);
  console.log('Saved rewards_card_bg.png');
}

createCardBg().catch(console.error);
