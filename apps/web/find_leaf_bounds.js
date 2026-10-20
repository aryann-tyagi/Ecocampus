
const sharp = require('sharp');
const fs = require('fs');

async function findLeafPixels() {
  const cardPath = 'C:/Users/aryan/.gemini/antigravity-ide/brain/8bc2c1e8-6817-41ed-9cd6-7d1cf02620cd/scratch/crop_card.png';
  const cardRaw = await sharp(cardPath).raw().toBuffer({ resolveWithObject: true });
  const { data, info } = cardRaw;
  const { width, height, channels } = info;

  // Let's find green pixels (g - r > 30 and g - b > 30) in specific zones:
  // Zone 1: top-left sky x: 50..150, y: 20..100
  // Zone 2: top-right mascot x: 280..350, y: 10..90
  // Zone 3: mid-right mascot x: 320..380, y: 90..170

  function getBounds(x0, y0, x1, y1) {
    let minX = 9999, maxX = 0, minY = 9999, maxY = 0;
    for (let y = y0; y <= y1; y++) {
      for (let x = x0; x <= x1; x++) {
        const idx = (y * width + x) * channels;
        const r = data[idx], g = data[idx+1], b = data[idx+2];
        if (g - r > 30 && g - b > 30 && r < 200) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }
    return { minX, maxX, minY, maxY };
  }

  console.log('Leaf 1:', getBounds(50, 20, 150, 100));
  console.log('Leaf 2:', getBounds(280, 10, 350, 90));
  console.log('Leaf 3:', getBounds(320, 90, 380, 170));
}

findLeafPixels().catch(console.error);
