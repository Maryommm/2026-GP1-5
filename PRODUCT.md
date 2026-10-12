# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

One Flutter codebase that ships to Android and iPhone with a single shared Ethmar look (not separate Material/Cupertino designs). Native conventions still apply: safe areas, system back gesture, text scaling.

## Users

Beginner home gardeners in Saudi Arabia, growing in pots, on balconies or in small yards, often for the first time. They read Arabic or English (the app is fully bilingual, RTL and LTR).

## Product Purpose

Ethmar (إثمار) is a friendly gardening companion. Its first feature is crop recommendation: it reads the user's location and today's weather and suggests crops that suit those conditions, so a beginner knows what is realistic to grow right now.

## Positioning

Recommendations are tied to the user's own local weather today, explained in plain beginner language, in Arabic and English, by a friendly character, not a generic crop encyclopedia.

## Operating Context

- Opened from the home screen. The flow is: find location, check weather, then show recommended crops.
- Location and weather will come from Google APIs and the recommendations from a model. Today the service returns sample data after a 3-second delay (`ethmar/lib/services/crop_recommendation_service.dart`).
- Each crop has: name, category (fruit, vegetable, herb, grain, legume), a one-line reason, a temperature range, how often to water, the season, and days to harvest. Conditions are: city, temperature, humidity and sky.

## Capabilities and Constraints

- The recommendation screen is browse-only for now: no "plant this", saving or comparing yet.
- Firebase auth and Firestore are used for accounts and profiles.
- Undecided: whether recommendations will carry a match score or ranking from the model; whether more crop facts (difficulty, sun needs, container size) will be available.

## Brand Commitments

- Name: Ethmar / إثمار. Voice: warm, simple, encouraging, beginner-friendly.
- Ethmar buddy character illustrations and weather-day characters in `ethmar/assets/images/` are core brand assets.
- Arabic and English are equal; every screen must work in RTL.

## Evidence on Hand

- Sample crop data only (six crops for Riyadh, 31°C, sunny). No real model output, no user data, no testimonials. Don't invent scores, yields or claims the data doesn't support.

## Product Principles

1. Beginners first: plain words and no agronomy jargon. One clear idea per screen.
2. Grounded in *today*: every suggestion should visibly connect to the user's real conditions.
3. Bilingual by design, not by translation: layouts work equally well in RTL and LTR.
4. Friendly, not childish: the character brings warmth, and the information stays clear and trustworthy.
