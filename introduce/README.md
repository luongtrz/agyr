# agyr Landing Page

A modern, high-performance static marketing website for [rotate-agy](https://github.com/luongtrz/rotate-agy), built with **Vite**, **React 19**, **TypeScript**, and **Tailwind CSS v4**.

- **100% Client-Side & Static**: Builds to pure HTML, CSS, JS, and SVG assets in `dist/`. No server runtime or Node.js required in production.
- **Zero External Dependencies / CDNs**: No Google Fonts, unpkg, or third-party tracking scripts. 100% self-contained and private.
- **Responsive & Zero Horizontal Scroll**: Tested and verified across viewports from 320px mobile screens up to 4K displays.
- **Accessible & Motion-Safe**: Full support for `prefers-reduced-motion` and keyboard navigation.

---

## Development

Requires `node` (>= 20) and `pnpm`.

```bash
cd introduce
pnpm install
pnpm dev
```

Visit `http://localhost:5173/` in your browser.

---

## Production Build

```bash
cd introduce
pnpm build
```

The production output will be generated in `introduce/dist/`.

To test the production build locally:

```bash
pnpm preview
# or serve directly with Python
python3 -m http.server 8900 --directory dist
```

---

## Deployment Options

Because the build is completely static with relative asset paths (`base: './'`), `dist/` can be deployed to any static host:

### 1. Cloudflare Pages
- **Build command**: `pnpm build`
- **Build output directory**: `dist`
- **Root directory**: `introduce`

### 2. GitHub Pages
Deploy the contents of `introduce/dist` to the `gh-pages` branch or via a GitHub Actions workflow.

### 3. Nginx / Apache / Caddy
Copy the contents of `introduce/dist/` directly into your web server's document root (e.g. `/var/www/html/`).
