type Store = 'apple' | 'google';

const STORE_HOSTS: Record<Store, readonly string[]> = {
  apple: ['apps.apple.com'],
  google: ['play.google.com'],
};

/**
 * Accetta esclusivamente URL HTTPS dei due store ufficiali. Una variabile
 * vuota, con soli spazi o con un host diverso non deve trasformare lo stato
 * "in arrivo" in un link pubblico non valido.
 */
export const officialStoreUrl = (
  value: string | undefined,
  store: Store,
): string | undefined => {
  const candidate = value?.trim();
  if (!candidate) return undefined;

  try {
    const url = new URL(candidate);
    if (url.protocol !== 'https:') return undefined;
    if (!STORE_HOSTS[store].includes(url.hostname)) return undefined;
    return url.toString();
  } catch {
    return undefined;
  }
};
