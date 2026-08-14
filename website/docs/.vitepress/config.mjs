import { defineConfig } from 'vitepress'

// The site is served from https://<user>.github.io/Anything/, so every
// absolute asset path needs the repository name as a base. Getting this wrong
// is the single most common reason a VitePress site 404s its own CSS on
// GitHub Pages.
const base = '/Anything/'

export default defineConfig({
  title: 'Anything',
  description:
    'An operating system for software that does not exist yet. Describe what you need — Anything builds it, runs it, and keeps it.',
  lang: 'en-US',
  base,
  cleanUrls: true,
  lastUpdated: true,

  // A dead link in the docs is a broken promise to a reader. Fail the build.
  ignoreDeadLinks: false,

  head: [
    ['link', { rel: 'icon', href: `${base}app_icon.png`, type: 'image/png' }],
    ['meta', { name: 'theme-color', content: '#6C5CE7' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:title', content: 'Anything' }],
    [
      'meta',
      {
        property: 'og:description',
        content:
          'Describe what you need. Anything builds it, runs it, and keeps it. Local-first, open source.',
      },
    ],
    ['meta', { property: 'og:image', content: `${base}social-card.svg` }],
    ['meta', { name: 'twitter:card', content: 'summary_large_image' }],
  ],

  themeConfig: {
    logo: '/app_icon.png',
    siteTitle: 'Anything',

    nav: [
      { text: 'Guide', link: '/guide/what-is-anything' },
      { text: 'Architecture', link: '/architecture/overview' },
      { text: 'Examples', link: '/guide/examples' },
      { text: 'Roadmap', link: '/guide/roadmap' },
      {
        text: 'Community',
        items: [
          { text: 'Contributing', link: '/community/contributing' },
          { text: 'Support', link: '/community/support' },
          { text: 'Sponsors', link: '/community/sponsors' },
          {
            text: 'Discussions',
            link: 'https://github.com/PIYUSH-MISHRA-00/Anything/discussions',
          },
        ],
      },
    ],

    sidebar: {
      '/guide/': [
        {
          text: 'Getting Started',
          items: [
            { text: 'What is Anything?', link: '/guide/what-is-anything' },
            { text: 'Installation', link: '/guide/installation' },
            { text: 'Quick Start', link: '/guide/quick-start' },
          ],
        },
        {
          text: 'Concepts',
          items: [
            { text: 'Experiences', link: '/guide/experiences' },
            { text: 'AI & Knowledge', link: '/guide/ai' },
            { text: 'WebWeaveX', link: '/guide/webweavex' },
            { text: 'Kaalka', link: '/guide/kaalka' },
          ],
        },
        {
          text: 'Practical',
          items: [
            { text: 'Examples', link: '/guide/examples' },
            { text: 'Roadmap', link: '/guide/roadmap' },
            { text: 'FAQ', link: '/guide/faq' },
          ],
        },
      ],
      '/architecture/': [
        {
          text: 'Architecture',
          items: [
            { text: 'Overview', link: '/architecture/overview' },
            { text: 'Certification', link: '/architecture/certification' },
            { text: 'Reference', link: '/architecture/reference' },
          ],
        },
      ],
      '/community/': [
        {
          text: 'Community',
          items: [
            { text: 'Contributing', link: '/community/contributing' },
            { text: 'Support', link: '/community/support' },
            { text: 'Sponsors', link: '/community/sponsors' },
          ],
        },
      ],
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/PIYUSH-MISHRA-00/Anything' },
    ],

    search: { provider: 'local' },

    editLink: {
      pattern:
        'https://github.com/PIYUSH-MISHRA-00/Anything/edit/v2.0.0/website/docs/:path',
      text: 'Suggest a change to this page',
    },

    footer: {
      message:
        'Apache-2.0 licensed. Experiences you create with Anything are yours.',
      copyright: 'Copyright © 2026 Piyush Mishra and the Anything contributors',
    },

    outline: { level: [2, 3] },
  },
})
