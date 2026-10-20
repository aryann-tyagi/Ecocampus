
const sharp = require('sharp');
const fs = require('fs');

async function inspectOtherLeaves() {
  const cardPath = 'C:/Users/aryan/.gemini/antigravity-ide/brain/8bc2c1e8-6817-41ed-9cd6-7d1cf02620cd/scratch/crop_card.png';
  const cardRaw = await sharp(cardPath).raw().toBuffer({ resolveWithObject: true });
  const { data, info } = cardRaw;
  const { width, height, channels } = info;

  console.log('--- Leaf 2 (top right of mascot) ---');
  for (let y = 35; y <= 85; y += 3) {
    let row = `Y=${y.toString().padStart(2)}: `;
    for (let x = 290; x <= 335; x += 3) {
      const idx = (y * width + x) * channels;
      const r = data[idx], g = data[idx+1], b = data[idx+2];
      if (g > r + 30 && g > b + 30) {
        row += 'L ';
      } else {
        row += '. ';
      }
    }
    console.log(row);
  }

  console.log('--- Leaf 3 (lower right of mascot) ---');
  for (let y = 115; y <= 165; y += 3) {
    let row = `Y=${y.toString().padStart(2)}: `;
    for (let x = 325; x <= 375; x += 3) {
      const idx = (y * width + x) * channels;
      const r = data[idx], g = data[idx+1], b = data[idx+2];
      if (g > r + 30 && g > b + 30) {
        row += 'L ';
      } else {
        row += '. ';
      }
    }
    console.log(row);
  }
}

inspectOtherLeaves().catch(console.error);
