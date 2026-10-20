
const sharp = require('sharp');
const fs = require('fs');

async function createPristineCardBg() {
  const cardPath = 'C:/Users/aryan/.gemini/antigravity-ide/brain/8bc2c1e8-6817-41ed-9cd6-7d1cf02620cd/scratch/crop_card.png';
  const cardRaw = await sharp(cardPath).raw().toBuffer({ resolveWithObject: true });
  const { data, info } = cardRaw;
  const { width, height, channels } = info;

  const out = Buffer.from(data);

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
    out[idx] = Math.round(r);
    out[idx + 1] = Math.round(g);
    out[idx + 2] = Math.round(b);
  }

  // 1. Inpaint Leaf 1 (X: 82..122, Y: 44..92) completely clean
  for (let y = 44; y <= 92; y++) {
    const cLeft = getPixel(76, y);
    const cRight = getPixel(128, y);
    for (let x = 82; x <= 122; x++) {
      const t = (x - 76) / (128 - 76);
      setPixel(x, y, cLeft[0]*(1-t) + cRight[0]*t, cLeft[1]*(1-t) + cRight[1]*t, cLeft[2]*(1-t) + cRight[2]*t);
    }
  }

  // 2. Inpaint Leaf 2 (X: 288..332, Y: 44..90) completely clean
  for (let y = 44; y <= 90; y++) {
    const cLeft = getPixel(282, y);
    const cRight = getPixel(338, y);
    for (let x = 288; x <= 332; x++) {
      const t = (x - 282) / (338 - 282);
      setPixel(x, y, cLeft[0]*(1-t) + cRight[0]*t, cLeft[1]*(1-t) + cRight[1]*t, cLeft[2]*(1-t) + cRight[2]*t);
    }
  }

  // 3. Inpaint Leaf 3 (X: 325..362, Y: 120..185)
  for (let y = 120; y <= 185; y++) {
    const cLeft = getPixel(318, y);
    const cRight = getPixel(368, y);
    for (let x = 325; x <= 362; x++) {
      const orig = getPixel(x, y);
      if (orig[1] > orig[0] + 12 && orig[1] > orig[2] + 12) {
        const t = (x - 318) / (368 - 318);
        setPixel(x, y, cLeft[0]*(1-t) + cRight[0]*t, cLeft[1]*(1-t) + cRight[1]*t, cLeft[2]*(1-t) + cRight[2]*t);
      }
    }
  }

  // 4. Center Area (x: 362 to 748, y: 0 to 245)
  for (let x = 362; x <= 748; x++) {
    for (let y = 0; y < height; y++) {
      let r, g, b;
      if (y < 155) {
        const t = y / 155.0;
        const sun = Math.exp(-Math.pow((x - 560) / 140, 2)) * Math.exp(-Math.pow((y - 85) / 50, 2)) * 4;
        r = Math.min(255, 222 * (1 - t) + 238 * t + sun);
        g = Math.min(255, 247 * (1 - t) + 248 * t + sun);
        b = Math.min(255, 238 * (1 - t) + 242 * t + sun);
      } else {
        const t = (y - 155) / (height - 155);
        if (t < 0.45) {
          const u = t / 0.45;
          r = 238 * (1 - u) + 241 * u;
          g = 248 * (1 - u) + 249 * u;
          b = 242 * (1 - u) + 238 * u;
        } else {
          const u = (t - 0.45) / 0.55;
          r = 241 * (1 - u) + 205 * u;
          g = 249 * (1 - u) + 228 * u;
          b = 238 * (1 - u) + 160 * u;
        }
      }

      // Smooth feather at seams
      if (x < 368) {
        const u = (x - 362) / 6.0;
        const cLeft = getPixel(360, y);
        r = cLeft[0] * (1 - u) + r * u;
        g = cLeft[1] * (1 - u) + g * u;
        b = cLeft[2] * (1 - u) + b * u;
      } else if (x > 742) {
        const u = (x - 742) / 6.0;
        const cRight = getPixel(750, y);
        r = r * (1 - u) + cRight[0] * u;
        g = g * (1 - u) + cRight[1] * u;
        b = b * (1 - u) + cRight[2] * u;
      }

      setPixel(x, y, r, g, b);
    }
  }

  const outPath = 'F:/Code/Eco Campus/apps/mobile/assets/images/rewards/rewards_card_bg.png';
  await sharp(out, { raw: { width, height, channels } })
    .png()
    .toFile(outPath);
  console.log('Saved pristine rewards_card_bg.png');
}

createPristineCardBg().catch(console.error);
