import {
  createLocalJWKSet,
  exportJWK,
  generateKeyPair,
  SignJWT,
} from "jose";
import { beforeAll, describe, expect, it } from "vitest";

import {
  AuthenticationError,
  verifyFirebaseIdToken,
} from "../src/firebase-auth";
import type { Env } from "../src/types";

const PROJECT_ID = "ethmar-95aaf";
const env: Env = {
  CLOUDINARY_CLOUD_NAME: "test-cloud",
  CLOUDINARY_API_KEY: "test-key",
  CLOUDINARY_API_SECRET: "test-secret",
  FIREBASE_PROJECT_ID: PROJECT_ID,
  PROFILE_IMAGE_RATE_LIMITER: { limit: async () => ({ success: true }) },
};

let privateKey: CryptoKey;
let localKeys: ReturnType<typeof createLocalJWKSet>;

beforeAll(async () => {
  const pair = await generateKeyPair("RS256");
  privateKey = pair.privateKey;
  const publicJwk = await exportJWK(pair.publicKey);
  localKeys = createLocalJWKSet({
    keys: [{ ...publicJwk, alg: "RS256", kid: "test-key", use: "sig" }],
  });
});

interface TokenOptions {
  audience?: string;
  issuer?: string;
  subject?: string;
  expiresAt?: number;
  emailVerified?: boolean;
  signingKey?: CryptoKey;
  issuedAt?: number | string | null;
  authTime?: number | string | null;
}

async function token(options: TokenOptions = {}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const claims: Record<string, unknown> = {
    email_verified: options.emailVerified ?? true,
  };
  if (options.issuedAt !== null) claims.iat = options.issuedAt ?? now;
  if (options.authTime !== null) claims.auth_time = options.authTime ?? now;
  return new SignJWT(claims)
    .setProtectedHeader({ alg: "RS256", kid: "test-key" })
    .setIssuer(options.issuer ?? "https://securetoken.google.com/" + PROJECT_ID)
    .setAudience(options.audience ?? PROJECT_ID)
    .setSubject(options.subject ?? "firebase-user-123")
    .setExpirationTime(options.expiresAt ?? now + 300)
    .sign(options.signingKey ?? privateKey);
}

async function expectAuthCode(value: string, code: string): Promise<void> {
  try {
    await verifyFirebaseIdToken(value, env, localKeys);
    throw new Error("Expected authentication to fail.");
  } catch (error) {
    expect(error).toBeInstanceOf(AuthenticationError);
    expect((error as AuthenticationError).code).toBe(code);
  }
}

describe("Firebase ID token verification", () => {
  it("verifies the signature, audience, issuer, expiry, and email verification", async () => {
    const user = await verifyFirebaseIdToken(await token(), env, localKeys);
    expect(user).toEqual({ uid: "firebase-user-123", emailVerified: true });
  });

  it("rejects a token with a different audience", async () => {
    await expectAuthCode(await token({ audience: "other-project" }), "INVALID_TOKEN");
  });

  it("rejects a token with a different issuer", async () => {
    await expectAuthCode(await token({ issuer: "https://securetoken.google.com/other" }), "INVALID_TOKEN");
  });

  it("rejects an expired token", async () => {
    await expectAuthCode(
      await token({ expiresAt: Math.floor(Date.now() / 1000) - 1 }),
      "INVALID_TOKEN",
    );
  });

  it("rejects an unverified email", async () => {
    await expectAuthCode(await token({ emailVerified: false }), "EMAIL_NOT_VERIFIED");
  });

  it("rejects a token signed by an unknown key", async () => {
    const other = await generateKeyPair("RS256");
    await expectAuthCode(await token({ signingKey: other.privateKey }), "INVALID_TOKEN");
  });

  it("rejects missing iat or auth_time claims", async () => {
    await expectAuthCode(await token({ issuedAt: null }), "INVALID_TOKEN");
    await expectAuthCode(await token({ authTime: null }), "INVALID_TOKEN");
  });

  it("rejects iat or auth_time claims in the future", async () => {
    const future = Math.floor(Date.now() / 1000) + 60;
    await expectAuthCode(await token({ issuedAt: future }), "INVALID_TOKEN");
    await expectAuthCode(await token({ authTime: future }), "INVALID_TOKEN");
  });

  it("rejects non-numeric iat or auth_time claims", async () => {
    await expectAuthCode(await token({ issuedAt: "not-a-number" }), "INVALID_TOKEN");
    await expectAuthCode(await token({ authTime: "not-a-number" }), "INVALID_TOKEN");
  });
});
