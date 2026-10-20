
const sharp = require('sharp');
const fs = require('fs');

async function inspectLeafPositions() {
  const cardPath = 'C:/Users/aryan/.gemini/antigravity-ide/brain/8bc2c1e8-6817-41ed-9cd6-7d1cf02620cd/scratch/crop_card.png';
  const cardRaw = await sharp(cardPath).raw().toBuffer({ resolveWithObject: true });
  const { data, info } = cardRaw;
  const { width, height, channels } = info;

  // Let's print out the exact RGB values in a grid around Leaf 1 (top-left of mascot)
  // Mascot ear/arm is around x=110, y=140.
  // The floating leaf is higher up in the sky, between x: 80..120, y: 55..90
  for (let y = 50; y <= 90; y += 4) {
    let row = `Y=${y.toString().padStart(2)}: `;
    for (let x = 80; x <= 125; x += 3) {
      const idx = (y * width + x) * channels;
      const r = data[idx], g = data[idx+1], b = data[idx+2];
      // Leaf if G > R + 30
      if (g > r + 30 && g > b + 30) {
        row += 'L ';
      } else {
        row += '. ';
      }
    }
    console.log(row);
  }
}

inspectLeafPositions().catch(console.error);
