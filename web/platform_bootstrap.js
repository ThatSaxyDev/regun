// Run before either game script so phones and tablets only load the landing page.
(() => {
  const agent = navigator.userAgent;
  const android = /Android/i.test(agent);
  const ios = /iPad|iPhone|iPod/i.test(agent) ||
    (/Macintosh/i.test(agent) && navigator.maxTouchPoints > 1);

  if (android || ios) {
    document.getElementById('splash').remove();
    const link = document.getElementById('regun-store');
    const copy = document.getElementById('mobile-download-copy');
    const retry = document.getElementById('mobile-download-retry');
    const platform = android ? 'android' : 'ios';

    async function resolveStore() {
      retry.hidden = true;
      link.hidden = true;
      copy.textContent = 'Finding the mobile download…';
      try {
        const response = await fetch('mobile-store-links.json', { cache: 'no-store' });
        if (!response.ok) throw new Error('Store links unavailable');
        const links = await response.json();
        const url = new URL(links[platform]);
        if (url.protocol !== 'https:') throw new Error('Invalid store link');
        const labels = android
          ? { 'play.google.com': 'Open Google Play',
              'appdistribution.firebase.dev': 'Open Android beta',
              'appdistribution.firebase.google.com': 'Open Android beta' }
          : { 'apps.apple.com': 'Open the App Store',
              'testflight.apple.com': 'Get the iOS beta on TestFlight' };
        if (!Object.hasOwn(labels, url.hostname)) throw new Error('Invalid store link');
        link.href = url.href;
        link.textContent = labels[url.hostname];
        link.hidden = false;
        copy.textContent = 'Get the mobile app to play on this device.';
      } catch {
        copy.textContent = 'The mobile download is temporarily unavailable.';
        retry.hidden = false;
      }
    }

    document.getElementById('mobile-download').hidden = false;
    retry.addEventListener('click', resolveStore);
    resolveStore();
    return;
  }

  for (const source of [
    'assets/packages/flutter_soloud/web/init_soloud.js',
    'flutter_bootstrap.js',
  ]) {
    const script = document.createElement('script');
    script.async = false;
    script.src = source;
    document.body.append(script);
  }
})();
