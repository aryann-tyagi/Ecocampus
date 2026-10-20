
const sharp = require('sharp');
const fs = require('fs');

async function makeFinalCardBg() {
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

  // 1. Inpaint Leaf 1 (X: 84..120, Y: 46..90)
  for (let y = 44; y <= 90; y++) {
    const cLeft = getPixel(80, y);
    const cRight = getPixel(125, y);
    for (let x = 84; x <= 120; x++) {
      const t = (x - 80) / (125 - 80);
      setPixel(x, y, cLeft[0]*(1-t) + cRight[0]*t, cLeft[1]*(1-t) + cRight[1]*t, cLeft[2]*(1-t) + cRight[2]*t);
    }
  }

  // 2. Inpaint Leaf 2 (X: 286..335, Y: 44..90)
  for (let y = 44; y <= 90; y++) {
    const cLeft = getPixel(282, y);
    const cRight = getPixel(340, y);
    for (let x = 286; x <= 335; x++) {
      const t = (x - 282) / (340 - 282);
      setPixel(x, y, cLeft[0]*(1-t) + cRight[0]*t, cLeft[1]*(1-t) + cRight[1]*t, cLeft[2]*(1-t) + cRight[2]*t);
    }
  }

  // 3. Inpaint Leaf 3 (X: 320..380, Y: 120..190)
  for (let y = 120; y <= 190; y++) {
    const cLeft = getPixel(315, y);
    const cRight = getPixel(385, y);
    for (let x = 320; x <= 380; x++) {
      const orig = getPixel(x, y);
      // only replace if green leaf
      if (orig[1] > orig[0] + 15 && orig[1] > orig[2] + 15) {
        const t = (x - 315) / (385 - 315);
        setPixel(x, y, cLeft[0]*(1-t) + cRight[0]*t, cLeft[1]*(1-t) + cRight[1]*t, cLeft[2]*(1-t) + cRight[2]*t);
      }
    }
  }

  // 4. Center Area (x: 355 to 745, y: 0 to 245)
  for (let x = 355; x <= 745; x++) {
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

      if (x < 370) {
        const u = (x - 355) / 15.0;
        const orig = getPixel(x, y);
        if (orig[0] > 180 && orig[1] > 180) {
          r = orig[0] * (1 - u) + r * u;
          g = orig[1] * (1 - u) + g * u;
          b = orig[2] * (1 - u) + b * u;
        }
      } else if (x > 730) {
        const u = (x - 730) / 15.0;
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

  // 5. Inpaint behind badge (X: 745..890, Y: 35..185)
  // Behind the badge is the soft trees and lawn
  for (let y = 35; y <= 185; y++) {
    for (let x = 745; x <= 890; x++) {
      // Sample clean tree texture from X: 910..960
      const sampleX = 910 + ((x - 745) % 50);
      const c = getPixel(sampleX, y);

      let r = c[0], g = c[1], b = c[2];
      // Blend top with sky
      if (y < 60) {
        const u = (y - 35) / 25.0;
        const skyC = getPixel(x, 28);
        r = skyC[0] * (1 - u) + r * u;
        g = skyC[1] * (1 - u) + g * u;
        b = skyC[2] * (1 - u) + b * u;
      }
      // Blend left with center sky/lawn
      if (x < 765) {
        const u = (x - 745) / 20.0;
        const cLeft = getPixel(740, y);
        r = cLeft[0] * (1 - u) + r * u;
        g = cLeft[1] * (1 - u) + g * u;
        b = cLeft[2] * (1 - u) + b * u;
      }
      // Blend bottom with lawn
      if (y > 170) {
        const u = (y - 170) / 15.0;
        const cBot = getPixel(x, 190);
        r = r * (1 - u) + cBot[0] * u;
        g = g * (1 - u) + cBot[1] * u;
        b = b * (1 - u) + cBot[2] * u;
      }

      setPixel(x, y, r, g, b);
    }
  }

  // Smooth blur over x: 742..895, y: 32..188
  for (let pass = 0; pass < 3; pass++) {
    for (let y = 35; y <= 185; y++) {
      for (let x = 745; x <= 890; x++) {
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
  console.log('Saved final flawless rewards_card_bg.png');
}

makeFinalCardBg().catch(console.error);
