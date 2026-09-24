import { defineConfig } from 'vite';
import { viteSingleFile } from 'vite-plugin-singlefile';

// Produces dist/index.html: one self-contained file (code, worker and styles
// inlined) that can be opened directly in a browser, even offline.
export default defineConfig({
  base: './',
  plugins: [viteSingleFile()],
  worker: { format: 'iife' },
  build: { target: 'es2020', chunkSizeWarningLimit: 4000 },
});
