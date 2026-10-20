
const sharp = require('sharp');
const fs = require('fs');

async function fixCardCoordinates() {
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

  // 3. Inpaint Leaf 3 (X: 325..365, Y: 120..170)
  for (let y = 120; y <= 170; y++) {
    const cLeft = getPixel(315, y);
    const cRight = getPixel(370, y);
    for (let x = 325; x <= 365; x++) {
      const t = (x - 315) / (370 - 315);
      setPixel(x, y, cLeft[0]*(1-t) + cRight[0]*t, cLeft[1]*(1-t) + cRight[1]*t, cLeft[2]*(1-t) + cRight[2]*t);
    }
  }

  // 4. Center Area (x: 350 to 760, y: 0 to 245)
  // Perfectly smooth sky and rolling lawn
  for (let x = 350; x <= 760; x++) {
    for (let y = 0; y < height; y++) {
      let r, g, b;
      if (y < 155) {
        const t = y / 155.0;
        const sun = Math.exp(-Math.pow((x - 580) / 140, 2)) * Math.exp(-Math.pow((y - 85) / 50, 2)) * 4;
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

      if (x < 365) {
        const u = (x - 350) / 15.0;
        const orig = getPixel(x, y);
        if (orig[0] > 180 && orig[1] > 180) {
          r = orig[0] * (1 - u) + r * u;
          g = orig[1] * (1 - u) + g * u;
          b = orig[2] * (1 - u) + b * u;
        }
      } else if (x > 745) {
        const u = (x - 745) / 15.0;
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

  // 5. Inpaint behind badge (X: 755..915, Y: 10..175)
  // Fill with natural tree foliage by sampling from the lush trees on right (x: 920..965)
  for (let y = 10; y <= 180; y++) {
    for (let x = 755; x <= 915; x++) {
      // Map x to sampleX in 920..965
      const sampleX = 920 + ((x - 755) % 45);
      const c = getPixel(sampleX, y);
      
      // Near top (y < 45) blend into sky
      let r = c[0], g = c[1], b = c[2];
      if (y < 45) {
        const u = (y - 10) / 35.0;
        const skyC = getPixel(x, 8);
        r = skyC[0] * (1 - u) + r * u;
        g = skyC[1] * (1 - u) + g * u;
        b = skyC[2] * (1 - u) + b * u;
      }
      
      // Near left (x < 775) blend into center sky/lawn
      if (x < 775) {
        const u = (x - 755) / 20.0;
        const cLeft = getPixel(750, y);
        r = cLeft[0] * (1 - u) + r * u;
        g = cLeft[1] * (1 - u) + g * u;
        b = cLeft[2] * (1 - u) + b * u;
      }

      setPixel(x, y, r, g, b);
    }
  }

  // Smooth blur over the tree foliage region x: 755..920, y: 15..180
  for (let pass = 0; pass < 2; pass++) {
    for (let y = 15; y <= 178; y++) {
      for (let x = 757; x <= 918; x++) {
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
  console.log('Saved fixed rewards_card_bg.png');
}

fixCardCoordinates().catch(console.error);
