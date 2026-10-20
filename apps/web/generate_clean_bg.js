
const sharp = require('sharp');
const fs = require('fs');

async function generateCleanBackground() {
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

  // 1. Inpaint Leaf 1 (X: 84..118, Y: 46..88)
  for (let y = 46; y <= 88; y++) {
    const cLeft = getPixel(80, y);
    const cRight = getPixel(122, y);
    for (let x = 84; x <= 118; x++) {
      const t = (x - 80) / (122 - 80);
      setPixel(x, y, cLeft[0]*(1-t) + cRight[0]*t, cLeft[1]*(1-t) + cRight[1]*t, cLeft[2]*(1-t) + cRight[2]*t);
    }
  }

  // 2. Inpaint Leaf 2 (X: 288..332, Y: 44..88)
  for (let y = 44; y <= 88; y++) {
    const cLeft = getPixel(284, y);
    const cRight = getPixel(336, y);
    for (let x = 288; x <= 332; x++) {
      const t = (x - 284) / (336 - 284);
      setPixel(x, y, cLeft[0]*(1-t) + cRight[0]*t, cLeft[1]*(1-t) + cRight[1]*t, cLeft[2]*(1-t) + cRight[2]*t);
    }
  }

  // 3. Inpaint Leaf 3 (X: 330..375, Y: 115..160)
  // Behind leaf 3 is the sky and distant hill
  for (let y = 115; y <= 160; y++) {
    const cLeft = getPixel(324, y);
    const cRight = getPixel(382, y);
    for (let x = 330; x <= 375; x++) {
      const t = (x - 324) / (382 - 324);
      setPixel(x, y, cLeft[0]*(1-t) + cRight[0]*t, cLeft[1]*(1-t) + cRight[1]*t, cLeft[2]*(1-t) + cRight[2]*t);
    }
  }

  // 4. Center Area (x: 335 to 765, y: 0 to 245)
  // Clean continuous sky and grass landscape
  for (let x = 335; x <= 765; x++) {
    for (let y = 0; y < height; y++) {
      let r, g, b;
      if (y < 155) {
        // Sky: smooth vertical gradient
        const t = y / 155.0;
        const sun = Math.exp(-Math.pow((x - 600) / 130, 2)) * Math.exp(-Math.pow((y - 90) / 50, 2)) * 4;
        r = Math.min(255, 222 * (1 - t) + 238 * t + sun);
        g = Math.min(255, 247 * (1 - t) + 248 * t + sun);
        b = Math.min(255, 238 * (1 - t) + 242 * t + sun);
      } else {
        // Grass hill: smooth transition from horizon (y=155) to lush foreground (y=245)
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

      // Smooth horizontal blend on left (335..355) with existing scenery/rock flowers
      if (x < 355) {
        const u = (x - 335) / 20.0;
        const orig = getPixel(x, y);
        // Only blend if not the old text
        if (orig[0] > 180 && orig[1] > 180) {
          r = orig[0] * (1 - u) + r * u;
          g = orig[1] * (1 - u) + g * u;
          b = orig[2] * (1 - u) + b * u;
        }
      } else if (x > 745) {
        const u = (x - 745) / 20.0;
        const orig = getPixel(x, y);
        if (orig[0] > 180 && orig[1] > 180) {
          r = r * (1 - u) + orig[0] * u;
          g = g * (1 - u) + orig[1] * u;
          b = b * (1 - u) + orig[2] * u;
        }
      }

      setPixel(x, y, r, g, b);
    }
  }

  // 5. Inpaint behind badge (X: 765..915, Y: 140..295)
  // Fill with the lush green blurred trees matching the right side
  for (let y = 140; y <= 295; y++) {
    for (let x = 765; x <= 915; x++) {
      const cRight = getPixel(930, y);
      const cTop = getPixel(x, 130);
      const cBottom = getPixel(x, 240);

      const ty = (y - 140) / (295 - 140);
      const tx = (x - 765) / (915 - 765);

      const r = cTop[0] * (1 - ty) * 0.35 + cBottom[0] * ty * 0.35 + cRight[0] * tx * 0.30;
      const g = cTop[1] * (1 - ty) * 0.35 + cBottom[1] * ty * 0.35 + cRight[1] * tx * 0.30;
      const b = cTop[2] * (1 - ty) * 0.35 + cBottom[2] * ty * 0.35 + cRight[2] * tx * 0.30;
      setPixel(x, y, r, g, b);
    }
  }

  // Soft blur over badge area to smoothly blend foliage
  for (let pass = 0; pass < 3; pass++) {
    for (let y = 138; y <= 297; y++) {
      for (let x = 763; x <= 917; x++) {
        let sr = 0, sg = 0, sb = 0, cnt = 0;
        for (let dy = -2; dy <= 2; dy++) {
          for (let dx = -2; dx <= 2; dx++) {
            const c = getPixel(x + dx, y + dy);
            sr += c[0]; sg += c[1]; sb += c[2]; cnt++;
          }
        }
        setPixel(x, y, sr / cnt, sg / cnt, sb / cnt);
      }
    }
  }

  const outPath = 'F:/Code/Eco Campus/apps/mobile/assets/images/rewards/rewards_card_bg.png';
  await sharp(out, { raw: { width, height, channels } })
    .png()
    .toFile(outPath);
  console.log('Saved clean rewards_card_bg.png');
}

generateCleanBackground().catch(console.error);
