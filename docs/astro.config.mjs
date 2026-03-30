import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  site: 'https://ivannguyendev.github.io',
  base: '/agents',
  integrations: [
    starlight({
      title: 'AI Agents Builder',
      description:
        'Toolkit for finding, creating, and validating AI agent skills and workflows across 10 AI coding tools',
      social: [
        {
          icon: 'github',
          label: 'GitHub',
          href: 'https://github.com/ivannguyendev/agents',
        },
      ],
      sidebar: [
        { label: 'Home', slug: 'index' },
        { label: 'Changelog', slug: 'changelog' },
      ],
    }),
  ],
});
