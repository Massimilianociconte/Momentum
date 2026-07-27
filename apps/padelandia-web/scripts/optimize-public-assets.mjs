import { mkdir } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import sharp from 'sharp';

const root = resolve(import.meta.dirname, '..');
const iconSource = resolve(root, 'src/assets/brand/padelandia-app-icon.png');
const heroSource = resolve(
  root,
  'src/assets/generated/hero-desktop-source.png',
);

const outputs = [
  {
    path: 'public/favicon-32.png',
    task: sharp(iconSource).resize(32, 32).png({ compressionLevel: 9 }),
  },
  {
    path: 'public/apple-touch-icon.png',
    task: sharp(iconSource).resize(180, 180).png({ compressionLevel: 9 }),
  },
  {
    path: 'public/icon-192.png',
    task: sharp(iconSource).resize(192, 192).png({ compressionLevel: 9 }),
  },
  {
    path: 'public/icon-512.png',
    task: sharp(iconSource).resize(512, 512).png({ compressionLevel: 9 }),
  },
  {
    path: 'public/og-momentum.jpg',
    task: sharp(heroSource)
      .resize(1200, 630, { fit: 'cover', position: 'right' })
      .jpeg({ quality: 82, progressive: true, mozjpeg: true }),
  },
];

await Promise.all(
  outputs.map(async ({ path, task }) => {
    const destination = resolve(root, path);
    await mkdir(dirname(destination), { recursive: true });
    await task.toFile(destination);
  }),
);

console.log(`Optimized ${outputs.length} public assets.`);
