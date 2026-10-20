
const sharp = require('sharp');

async function findRockRightEdge() {
  const cardPath = 'C:/Users/aryan/.gemini/antigravity-ide/brain/8bc2c1e8-6817-41ed-9cd6-7d1cf02620cd/scratch/crop_card.png';
  const cardRaw = await sharp(cardPath).raw().toBuffer({ resolveWithObject: true });
  const { data, info } = cardRaw;
  const { width, height, channels } = info;

  // Let's print out what is at X: 330..375, Y: 140..240 in original crop_card
  // We want to find where the rock/leaves end and where the plain grass begins
  for (let y = 140; y < 240; y += 10) {
    let row = `Y=${y}: `;
    for (let x = 320; x < 380; x += 5) {
      const idx = (y * width + x) * channels;
      const r = data[idx], g = data[idx+1], b = data[idx+2];
      // Rock/daisy/leaf has non-sky, non-plain-grass color
      row += `[${x}:#${r.toString(16).padStart(2,'0')}${g.toString(16).padStart(2,'0')}${b.toString(16).padStart(2,'0')}] `;
    }
    console.log(row);
  }
}

findRockRightEdge().catch(console.error);
