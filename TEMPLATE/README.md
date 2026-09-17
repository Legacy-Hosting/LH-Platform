# Legacy Hosting website template

Reusable React/Vite starting point for Legacy Hosting dashboards and internal applications.

## Design system

- Keep all styling in `src/main.css`.
- Reuse the existing colors, typography, borders, spacing, cards, buttons, header, sidebar, and footer.
- Keep the application shell at exactly the browser viewport size.
- Only `.scroll-content` should scroll on desktop.
- Desktop navigation lives in the left sidebar.
- Phone navigation becomes the bottom icon bar.
- Preserve the live Europe/Oslo footer clock and Legacy Hosting copyright link.

## Start a new Legacy Hosting website

1. Copy this folder and rename the copy for the new project.
2. Change the package name in `package.json`.
3. Replace the sample content in `src/main.jsx` while preserving the shell structure.
4. Keep shared visual tokens at the top of `src/main.css`.
5. Run `npm install`, then `npm run dev`.

Do not copy `node_modules` or `dist` from another project.
