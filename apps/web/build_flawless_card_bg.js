
const sharp = require('sharp');
const fs = require('fs');

async function buildFlawlessCardBg() {
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

  // A. Inpaint Leaf 1 (X: 88..155, Y: 44..104)
  // Sky here has a gentle vertical gradient. Sample at x=75 and x=165
  for (let y = 42; y <= 106; y++) {
    const cLeft = getPixel(72, y);
    const cRight = getPixel(168, y);
    for (let x = 85; x <= 158; x++) {
      const t = (x - 72) / (168 - 72);
      setPixel(x, y, cLeft[0]*(1-t) + cRight[0]*t, cLeft[1]*(1-t) + cRight[1]*t, cLeft[2]*(1-t) + cRight[2]*t);
    }
  }

  // B. Inpaint Leaf 2 (X: 285..330, Y: 42..92)
  // Sample sky at x=275 and x=340
  for (let y = 40; y <= 95; y++) {
    const cLeft = getPixel(275, y);
    const cRight = getPixel(342, y);
    for (let x = 282; x <= 335; x++) {
      const t = (x - 275) / (342 - 275);
      setPixel(x, y, cLeft[0]*(1-t) + cRight[0]*t, cLeft[1]*(1-t) + cRight[1]*t, cLeft[2]*(1-t) + cRight[2]*t);
    }
  }

  // C. Inpaint Leaf 3 (X: 320..385, Y: 120..175)
  // Sample at x=310 and x=395
  for (let y = 118; y <= 178; y++) {
    const cLeft = getPixel(310, y);
    const cRight = getPixel(395, y);
    for (let x = 318; x <= 390; x++) {
      const t = (x - 310) / (395 - 310);
      setPixel(x, y, cLeft[0]*(1-t) + cRight[0]*t, cLeft[1]*(1-t) + cRight[1]*t, cLeft[2]*(1-t) + cRight[2]*t);
    }
  }

  // D. Inpaint Center (X: 360..765, Y: 15..235)
  // Perfectly smooth sky and rolling hill matching the reference
  for (let x = 360; x <= 765; x++) {
    for (let y = 15; y < 235; y++) {
      let r, g, b;
      if (y < 160) {
        // Sky gradient: at y=15: #DAF5EC (218, 245, 236), at y=160: #EEF8F2 (238, 248, 242)
        const t = (y - 15) / (160 - 15);
        // Soft sunny warmth towards center
        const sun = Math.exp(-Math.pow((x - 620) / 120, 2)) * Math.exp(-Math.pow((y - 80) / 60, 2)) * 6;
        r = Math.min(255, 218 * (1 - t) + 238 * t + sun);
        g = Math.min(255, 245 * (1 - t) + 248 * t + sun);
        b = Math.min(255, 236 * (1 - t) + 242 * t + sun);
      } else {
        // Rolling green lawn: at y=160: #EEF8F2, at y=190: #F1F9EE, at y=235: #CFE6A7
        const t = (y - 160) / (235 - 160);
        if (t < 0.4) {
          const u = t / 0.4;
          r = 238 * (1 - u) + 241 * u;
          g = 248 * (1 - u) + 249 * u;
          b = 242 * (1 - u) + 238 * u;
        } else {
          const u = (t - 0.4) / 0.6;
          r = 241 * (1 - u) + 207 * u;
          g = 249 * (1 - u) + 230 * u;
          b = 238 * (1 - u) + 167 * u;
        }
      }

      // Smooth horizontal blend near boundaries
      if (x < 380) {
        const blend = (x - 360) / 20.0;
        const orig = getPixel(360, y);
        r = orig[0] * (1 - blend) + r * blend;
        g = orig[1] * (1 - blend) + g * blend;
        b = orig[2] * (1 - blend) + b * blend;
      } else if (x > 745) {
        const blend = (x - 745) / 20.0;
        const orig = getPixel(765, y);
        r = r * (1 - blend) + orig[0] * blend;
        g = g * (1 - blend) + orig[1] * blend;
        b = b * (1 - blend) + orig[2] * blend;
      }

      setPixel(x, y, r, g, b);
    }
  }

  // E. Inpaint behind badge (X: 775..900, Y: 155..285)
  // Behind the badge is the lush tree foliage and hill
  for (let y = 155; y <= 285; y++) {
    for (let x = 775; x <= 900; x++) {
      // Sample tree foliage from the right (x=925) and top (y=140)
      const cRight = getPixel(925, y);
      const cTop = getPixel(x, 140);
      const cBottom = getPixel(x, 295);

      const ty = (y - 155) / (285 - 155);
      const tx = (x - 775) / (900 - 775);

      // Natural blurred green tree foliage
      const r = cTop[0] * (1 - ty) * 0.4 + cBottom[0] * ty * 0.3 + cRight[0] * tx * 0.3;
      const g = cTop[1] * (1 - ty) * 0.4 + cBottom[1] * ty * 0.3 + cRight[1] * tx * 0.3;
      const b = cTop[2] * (1 - ty) * 0.4 + cBottom[2] * ty * 0.3 + cRight[2] * tx * 0.3;
      setPixel(x, y, r, g, b);
    }
  }

  // Smooth blur over badge area
  for (let pass = 0; pass < 2; pass++) {
    for (let y = 153; y <= 287; y++) {
      for (let x = 773; x <= 902; x++) {
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
  console.log('Saved flawless rewards_card_bg.png');
}

buildFlawlessCardBg().catch(console.error);
