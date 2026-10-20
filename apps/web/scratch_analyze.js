
const sharp = require('sharp');
const fs = require('fs');

async function run() {
  const inputPath = 'C:/Users/aryan/.gemini/antigravity-ide/brain/8bc2c1e8-6817-41ed-9cd6-7d1cf02620cd/scratch/crop_card.png';
  const img = sharp(inputPath);
  const metadata = await img.metadata();
  console.log('Metadata:', metadata.width, metadata.height, metadata.channels);
}

run().catch(console.error);
