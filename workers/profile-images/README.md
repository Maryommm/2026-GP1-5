# Ethmar profile image worker

Cloudflare Worker for public Cloudinary profile images. Upload and deletion are
protected by Firebase Authentication. The Worker never accepts a UID, folder,
or Cloudinary public ID from the client; it derives the UID from a verified
Firebase ID token and uses this fixed public ID:

    ethmar/profile-images/{uid}/profile

## Endpoints

### POST /v1/profile-image

Send multipart/form-data with exactly one field named file and an Authorization
header containing a Firebase ID token as a Bearer token. JPEG, PNG, and WebP are
accepted. The file limit is 5 MB and the complete request limit is 6 MB.

The upload overwrites the user's previous profile image, invalidates the old
Cloudinary delivery cache, and returns the new Cloudinary version and secure
public URL. An incoming Cloudinary transformation limits the stored original to
4096 x 4096 pixels, applies `fl_force_strip`, and normalizes the stored result
to WebP. This removes EXIF (including GPS), IPTC, and XMP metadata before the
public original is stored, including the `DigitalSourceType` XMP tag that
Cloudinary otherwise preserves in transformed JPEG and PNG outputs.

### DELETE /v1/profile-image

Send no request body. Deleting a missing image is successful and returns the
status not_found rather than an error.

## Cloudflare bindings

Configure these values as Cloudflare production variables/secrets. Never put
real values in this repository or in a Flutter build:

    CLOUDINARY_CLOUD_NAME
    CLOUDINARY_API_KEY
    CLOUDINARY_API_SECRET
    FIREBASE_PROJECT_ID

The Worker also requires a `PROFILE_IMAGE_RATE_LIMITER` Workers Rate Limiting
binding. `wrangler.jsonc` configures it for 6 operations per 60 seconds, keyed
in code by the UID from the verified Firebase token. Confirm that Rate Limiting
bindings are available for the target Cloudflare account and that namespace ID
`9500501` is not already used for an unrelated limiter before deployment. Wrangler
4.36.0 or later is required; this project pins a newer compatible version.

The Firebase project ID is used as both the expected token audience and in the
expected issuer. Token signatures are checked against Google's Firebase secure
token JWKS. Tokens must be unexpired, contain valid non-future `iat` and
`auth_time` claims, and contain `email_verified=true`.

## Local checks

Copy .dev.vars.example to .dev.vars only for local development, then supply
local values. The real .dev.vars file is ignored by Git.

    npm install
    npm run typecheck
    npm test

Tests use local mocks and test signing keys. They do not call Firebase,
Cloudinary, or the deployed Worker.
