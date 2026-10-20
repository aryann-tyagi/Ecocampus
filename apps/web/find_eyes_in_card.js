
const sharp = require('sharp');
const fs = require('fs');

async function findEyesInCard() {
  const cardPath = 'C:/Users/aryan/.gemini/antigravity-ide/brain/8bc2c1e8-6817-41ed-9cd6-7d1cf02620cd/scratch/crop_card.png';
  const cardRaw = await sharp(cardPath).raw().toBuffer({ resolveWithObject: true });
  const { data, info } = cardRaw;
  const { width, height, channels } = info;

  // Mascot face is roughly X: 140..260, Y: 100..160
  // Dark pupils: R < 35, G < 35, B < 35
  let leftPupils = [], rightPupils = [];
  for (let y = 90; y < 170; y++) {
    for (let x = 140; x < 265; x++) {
      const idx = (y * width + x) * channels;
      const r = data[idx], g = data[idx+1], b = data[idx+2];
      if (r < 35 && g < 35 && b < 35) {
        if (x < 205) {
          leftPupils.push({x, y});
        } else {
          rightPupils.push({x, y});
        }
      }
    }
  }

  function stats(arr) {
    const xs = arr.map(p => p.x), ys = arr.map(p => p.y);
    const minX = Math.min(...xs), maxX = Math.max(...xs);
    const minY = Math.min(...ys), maxY = Math.max(...ys);
    return {
      minX, maxX, minY, maxY,
      cx: (minX + maxX) / 2,
      cy: (minY + maxY) / 2,
      w: maxX - minX + 1,
      h: maxY - minY + 1
    };
  }

  console.log('Left pupil in crop_card:', stats(leftPupils));
  console.log('Right pupil in crop_card:', stats(rightPupils));

  // Also let's find the white eye sockets (R>245, G>245, B>245 around pupils)
  function eyeSocketStats(pupil) {
    let xs = [], ys = [];
    for (let y = Math.round(pupil.cy - 30); y <= Math.round(pupil.cy + 30); y++) {
      for (let x = Math.round(pupil.cx - 30); x <= Math.round(pupil.cx + 30); x++) {
        const idx = (y * width + x) * channels;
        const r = data[idx], g = data[idx+1], b = data[idx+2];
        // eye whites or pupil
        if ((r > 240 && g > 240 && b > 240) || (r < 35 && g < 35 && b < 35)) {
          xs.push(x);
          ys.push(y);
        }
      }
    }
    const minX = Math.min(...xs), maxX = Math.max(...xs);
    const minY = Math.min(...ys), maxY = Math.max(...ys);
    return {
      minX, maxX, minY, maxY,
      cx: (minX + maxX) / 2,
      cy: (minY + maxY) / 2,
      w: maxX - minX + 1,
      h: maxY - minY + 1
    };
  }

  const leftEye = eyeSocketStats(stats(leftPupils));
  const rightEye = eyeSocketStats(stats(rightPupils));
  console.log('Left eye socket in crop_card:', leftEye);
  console.log('Right eye socket in crop_card:', rightEye);
}

findEyesInCard().catch(console.error);
