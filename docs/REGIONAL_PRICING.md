# Regional pricing proposal — NOT ACTIVATED

The country/territory worksheet `REGIONAL_PRICE_PROPOSAL.csv` has one row for each of 249 ISO 3166-1 entries from this computer's iso-codes data. Inclusion is a planning inventory, not a statement that Google Play billing/distribution is available there.

USD reference proposals are the owner's supplied amounts: US/Canada/Western Europe 9.99, Japan/South Korea 8.99, Uzbekistan/Kyrgyzstan 3.99, Kazakhstan 4.99, India 2.99. Other entries retain the owner's 4.99–9.99 review range. Currency conversion, taxes, minimum prices, supported countries, exchange rates and purchasing-power assessments must be checked in the actual Play Console; no invented final local prices are supplied.

Review each row, set a proposed local-currency price through the **same** non-consumable `bilga_lifetime_unlock` product, export the Console proposal for owner review, and activate only after explicit approval. Do not activate this worksheet automatically. Price changes must not remove valid lifetime entitlements. No location permission, device fingerprint, custom regional payment path or region-specific feature tier is used.

The running app displays `ProductDetails.price`; USD reference prices do not appear as hardcoded purchase amounts in app code. Verify the actual price and currency with licensed test accounts in the target countries before release.
