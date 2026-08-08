# Anything — website

The public site and documentation, built with [VitePress](https://vitepress.dev)
and deployed to GitHub Pages by `.github/workflows/website.yml`.

```bash
cd website
npm install
npm run dev      # http://localhost:5173
npm run build    # -> docs/.vitepress/dist
```

Why VitePress rather than Docusaurus, Astro or MkDocs: see
`WEBSITE_ARCHITECTURE.md` in the IS-P02 deliverables. Short version — this
repository already has 178 markdown documents, one Dart developer, and no
JavaScript anywhere. VitePress is markdown-first, has built-in search, and
needs one dependency.

**Content lives in `docs/`.** Pages that would duplicate the repository's own
documentation link to it on GitHub instead of copying it — the same
no-duplication rule the repository follows internally.
