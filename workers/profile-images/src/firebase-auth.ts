import {
  createRemoteJWKSet,
  jwtVerify,
  type JWTVerifyGetKey,
} from "jose";

import type { AuthenticatedUser, Env } from "./types";

const FIREBASE_JWKS_URL = new URL(
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
);
const UID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;

const remoteKeySets = new Map<string, JWTVerifyGetKey>();

export class AuthenticationError extends Error {
  constructor(
    readonly code: "AUTH_REQUIRED" | "INVALID_TOKEN" | "EMAIL_NOT_VERIFIED",
    readonly status: 401 | 403,
    readonly publicMessage: string,
  ) {
    super(code);
    this.name = "AuthenticationError";
  }
}

export function readBearerToken(request: Request): string {
  const header = request.headers.get("authorization");
  if (!header) {
    throw new AuthenticationError(
      "AUTH_REQUIRED",
      401,
      "A Firebase ID token is required.",
    );
  }

  const match = /^Bearer ([^\s]+)$/.exec(header);
  if (!match) {
    throw new AuthenticationError(
      "INVALID_TOKEN",
      401,
      "The Firebase ID token is invalid or expired.",
    );
  }
  return match[1];
}

function remoteKeySet(projectId: string): JWTVerifyGetKey {
  const existing = remoteKeySets.get(projectId);
  if (existing) return existing;
  const created = createRemoteJWKSet(FIREBASE_JWKS_URL);
  remoteKeySets.set(projectId, created);
  return created;
}

export async function verifyFirebaseIdToken(
  token: string,
  env: Env,
  keySet?: JWTVerifyGetKey,
): Promise<AuthenticatedUser> {
  const projectId = env.FIREBASE_PROJECT_ID?.trim();
  if (!projectId) throw new Error("Firebase authentication is not configured.");

  let payload;
  try {
    ({ payload } = await jwtVerify(token, keySet ?? remoteKeySet(projectId), {
      algorithms: ["RS256"],
      audience: projectId,
      issuer: "https://securetoken.google.com/" + projectId,
    }));
  } catch {
    throw new AuthenticationError(
      "INVALID_TOKEN",
      401,
      "The Firebase ID token is invalid or expired.",
    );
  }

  const now = Math.floor(Date.now() / 1000);
  if (typeof payload.exp !== "number" || payload.exp <= now) {
    throw new AuthenticationError(
      "INVALID_TOKEN",
      401,
      "The Firebase ID token is invalid or expired.",
    );
  }
  if (
    typeof payload.iat !== "number"
    || !Number.isFinite(payload.iat)
    || payload.iat < 0
    || payload.iat > now
    || typeof payload.auth_time !== "number"
    || !Number.isFinite(payload.auth_time)
    || payload.auth_time < 0
    || payload.auth_time > now
  ) {
    throw new AuthenticationError(
      "INVALID_TOKEN",
      401,
      "The Firebase ID token is invalid or expired.",
    );
  }
  if (typeof payload.sub !== "string" || !UID_PATTERN.test(payload.sub)) {
    throw new AuthenticationError(
      "INVALID_TOKEN",
      401,
      "The Firebase ID token is invalid or expired.",
    );
  }
  if (payload.email_verified !== true) {
    throw new AuthenticationError(
      "EMAIL_NOT_VERIFIED",
      403,
      "A verified email address is required.",
    );
  }

  return { uid: payload.sub, emailVerified: true };
}
