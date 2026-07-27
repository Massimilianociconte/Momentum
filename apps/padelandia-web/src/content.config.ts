import { glob } from 'astro/loaders';
import { defineCollection, z } from 'astro:content';

/**
 * Articoli del blog. I file Markdown vengono creati anche dal Worker
 * editoriale (workers/blog-publisher): lo schema è il contratto condiviso
 * tra pipeline editoriale e sito, quindi ogni campo nuovo va aggiunto in
 * entrambi i punti.
 */
const blog = defineCollection({
  loader: glob({
    base: './src/content/blog',
    pattern: '**/*.{md,mdx}',
  }),

  schema: z.object({
    title: z.string().min(1),
    description: z.string().min(1),

    pubDate: z.coerce.date(),
    updatedDate: z.coerce.date().optional(),

    // Le bozze restano nel repository ma non generano pagine pubbliche.
    draft: z.boolean().default(true),

    author: z.string().default('Momentum'),
    category: z.string().optional(),
    tags: z.array(z.string()).default([]),

    featuredImage: z.string().optional(),
    featuredImageAlt: z.string().optional(),

    seoTitle: z.string().optional(),
    canonicalUrl: z.string().url().optional(),
  }),
});

export const collections = { blog };
