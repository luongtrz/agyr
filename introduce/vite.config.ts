import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

// base './' keeps the build portable (any sub-path or document root).
export default defineConfig({
  base: './',
  plugins: [react(), tailwindcss()],
});
