# Samsung Tizen Watch Status

Momentum intentionally contains no new Tizen watch binary.

Samsung has discontinued distribution of Tizen-based watch apps: developers
can no longer register new apps or updates in Seller Portal. Existing listings
may remain available, but Momentum has no grandfathered listing to update.
Creating a new package would therefore produce an unpublishable artifact and a
false compatibility promise.

The production behavior is explicit:

- the compatibility catalog marks Galaxy Watch Tizen as `RETIRED`;
- the mobile onboarding shows migration guidance, not simulated pairing;
- Tizen devices never qualify as scoring-capable or as a Duo Mode watch;
- Galaxy Watch4 and newer use the maintained native Wear OS module distributed
  through Google Play.

This status should be reviewed only if Samsung publishes a new official
distribution path. Do not revive legacy SAP/Tizen code based on archived SDK
documentation alone.

Official notice:
https://developer.samsung.com/galaxy-watch-tizen/notice.html
