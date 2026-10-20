
const sharp = require('sharp');
const fs = require('fs');

async function extractBadge() {
  const originalPath = 'C:/Users/aryan/.gemini/antigravity-ide/brain/8bc2c1e8-6817-41ed-9cd6-7d1cf02620cd/.user_uploaded/media_1792493821838.png';
  const raw = await sharp(originalPath).raw().toBuffer({ resolveWithObject: true });
  const { data, info } = raw;
  const { width, height, channels } = info;

  const cx = 837.5;
  const cy = 225.5;
  const pad = 12; // include outer shadow
  const boxW = 160;
  const boxH = 150;
  const startX = Math.round(cx - boxW / 2);
  const startY = Math.round(cy - boxH / 2);

  // Crop box
  const cropped = Buffer.alloc(boxW * boxH * 4);

  // SVG mask for rounded hexagon
  // Let's create an SVG with the exact rounded hexagon path
  // Vertices of the hexagon around (boxW/2, boxH/2):
  // Let's test standard polygon:
  // Points: top: (80, 10), top-right: (144, 47), bottom-right: (144, 103), bottom: (80, 140), bottom-left: (16, 103), top-left: (16, 47)
  
  // First let's extract the raw crop
  const rawCrop = await sharp(originalPath)
    .extract({ left: startX, top: startY, width: boxW, height: boxH })
    .png()
    .toBuffer();

  fs.writeFileSync('C:/Users/aryan/.gemini/antigravity-ide/brain/8bc2c1e8-6817-41ed-9cd6-7d1cf02620cd/scratch/badge_exact_crop.png', rawCrop);
  console.log('Saved badge_exact_crop.png');
}

extractBadge().catch(console.error);
