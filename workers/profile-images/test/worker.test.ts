import { beforeEach, describe, expect, it, vi } from "vitest";

import { CloudinaryError, profilePublicId } from "../src/cloudinary";
import { AuthenticationError } from "../src/firebase-auth";
import { createWorker } from "../src/index";
import type {
  DeletedProfileImage,
  Env,
  UploadedProfileImage,
  WorkerDependencies,
} from "../src/types";

const ONE_PIXEL_PNG = Uint8Array.from(
  atob("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="),
  (character) => character.charCodeAt(0),
);

const env: Env = {
  CLOUDINARY_CLOUD_NAME: "test-cloud",
  CLOUDINARY_API_KEY: "test-key",
  CLOUDINARY_API_SECRET: "do-not-expose-this-secret",
  FIREBASE_PROJECT_ID: "ethmar-95aaf",
  PROFILE_IMAGE_RATE_LIMITER: { limit: async () => ({ success: true }) },
};

function uploadRequest(token = "valid-token", extra?: [string, string]): Request {
  const form = new FormData();
  form.set("file", new File([ONE_PIXEL_PNG], "profile.png", { type: "image/png" }));
  if (extra) form.set(extra[0], extra[1]);
  return new Request("https://worker.test/v1/profile-image", {
    method: "POST",
    headers: { authorization: "Bearer " + token },
    body: form,
  });
}

function uploaded(uid: string, version: number): UploadedProfileImage {
  return {
    publicId: profilePublicId(uid),
    secureUrl: "https://res.cloudinary.com/test-cloud/image/upload/v"
      + version + "/" + profilePublicId(uid) + ".png",
    version,
    format: "png",
    width: 1,
    height: 1,
    bytes: ONE_PIXEL_PNG.length,
  };
}

function defaultMocks() {
  const verifyToken = vi.fn<WorkerDependencies["verifyToken"]>(async (token) => {
    if (token !== "valid-token") {
      throw new AuthenticationError(
        "INVALID_TOKEN",
        401,
        "The Firebase ID token is invalid or expired.",
      );
    }
    return { uid: "user-a", emailVerified: true };
  });
  const uploadProfileImage = vi.fn<WorkerDependencies["uploadProfileImage"]>(
    async (_env, uid) => uploaded(uid, 1),
  );
  const deleteProfileImage = vi.fn<WorkerDependencies["deleteProfileImage"]>(
    async (_env, uid): Promise<DeletedProfileImage> => ({
      publicId: profilePublicId(uid),
      deleted: true,
      notFound: false,
    }),
  );
  return { verifyToken, uploadProfileImage, deleteProfileImage };
}

describe("profile image Worker", () => {
  beforeEach(() => vi.restoreAllMocks());

  it("rejects a request without an Authorization header", async () => {
    const mocks = defaultMocks();
    const worker = createWorker(mocks);
    const response = await worker.fetch(
      new Request("https://worker.test/v1/profile-image", { method: "POST" }),
      env,
    );

    expect(response.status).toBe(401);
    expect(await response.json()).toMatchObject({ error: { code: "AUTH_REQUIRED" } });
    expect(mocks.verifyToken).not.toHaveBeenCalled();
    expect(mocks.uploadProfileImage).not.toHaveBeenCalled();
  });

  it("rejects an invalid Firebase ID token without reflecting it", async () => {
    const mocks = defaultMocks();
    const worker = createWorker(mocks);
    const response = await worker.fetch(uploadRequest("secret-invalid-token"), env);
    const body = JSON.stringify(await response.json());

    expect(response.status).toBe(401);
    expect(body).toContain("INVALID_TOKEN");
    expect(body).not.toContain("secret-invalid-token");
    expect(body).not.toContain(env.CLOUDINARY_API_SECRET);
  });

  it("rejects an unverified email", async () => {
    const mocks = defaultMocks();
    mocks.verifyToken.mockRejectedValueOnce(
      new AuthenticationError(
        "EMAIL_NOT_VERIFIED",
        403,
        "A verified email address is required.",
      ),
    );
    const response = await createWorker(mocks).fetch(uploadRequest(), env);

    expect(response.status).toBe(403);
    expect(await response.json()).toMatchObject({ error: { code: "EMAIL_NOT_VERIFIED" } });
  });

  it("rate limits by verified UID before reading the upload body", async () => {
    const mocks = defaultMocks();
    const limit = vi.fn(async () => ({ success: false }));
    const unreadBody = {
      getReader() {
        throw new Error("The request body must not be read after rate limiting.");
      },
    } as unknown as ReadableStream<Uint8Array>;
    const request = {
      url: "https://worker.test/v1/profile-image",
      method: "POST",
      headers: new Headers({
        authorization: "Bearer valid-token",
        "content-type": "multipart/form-data; boundary=test",
      }),
      body: unreadBody,
    } as Request;

    const response = await createWorker(mocks).fetch(request, {
      ...env,
      PROFILE_IMAGE_RATE_LIMITER: { limit },
    });

    expect(response.status).toBe(429);
    expect(response.headers.get("retry-after")).toBe("60");
    expect(await response.json()).toMatchObject({ error: { code: "RATE_LIMIT_EXCEEDED" } });
    expect(limit).toHaveBeenCalledWith({ key: "user-a" });
    expect(mocks.uploadProfileImage).not.toHaveBeenCalled();
  });

  it("rejects an unsupported file before calling Cloudinary", async () => {
    const mocks = defaultMocks();
    const form = new FormData();
    form.set("file", new File(["GIF89a"], "profile.gif", { type: "image/gif" }));
    const response = await createWorker(mocks).fetch(
      new Request("https://worker.test/v1/profile-image", {
        method: "POST",
        headers: { authorization: "Bearer valid-token" },
        body: form,
      }),
      env,
    );

    expect(response.status).toBe(415);
    expect(mocks.uploadProfileImage).not.toHaveBeenCalled();
  });

  it("rejects a client-provided UID, folder, or public ID", async () => {
    for (const field of ["uid", "folder", "public_id"]) {
      const mocks = defaultMocks();
      const response = await createWorker(mocks).fetch(
        uploadRequest("valid-token", [field, "user-b"]),
        env,
      );
      expect(response.status).toBe(400);
      expect(await response.json()).toMatchObject({ error: { code: "UNEXPECTED_FIELD" } });
      expect(mocks.uploadProfileImage).not.toHaveBeenCalled();
    }
  });

  it("overwrites the same fixed public ID and returns the new version", async () => {
    const mocks = defaultMocks();
    mocks.uploadProfileImage
      .mockResolvedValueOnce(uploaded("user-a", 41))
      .mockResolvedValueOnce(uploaded("user-a", 42));
    const worker = createWorker(mocks);

    const first = await worker.fetch(uploadRequest(), env);
    const second = await worker.fetch(uploadRequest(), env);
    const firstBody = await first.json() as { image: UploadedProfileImage };
    const secondBody = await second.json() as { image: UploadedProfileImage };

    expect(firstBody.image.publicId).toBe("ethmar/profile-images/user-a/profile");
    expect(secondBody.image.publicId).toBe(firstBody.image.publicId);
    expect(firstBody.image.version).toBe(41);
    expect(secondBody.image.version).toBe(42);
    expect(mocks.uploadProfileImage).toHaveBeenCalledTimes(2);
    expect(mocks.uploadProfileImage.mock.calls[0][1]).toBe("user-a");
    expect(mocks.uploadProfileImage.mock.calls[1][1]).toBe("user-a");
  });

  it("derives different Cloudinary ownership from different verified users", async () => {
    const mocks = defaultMocks();
    mocks.verifyToken.mockImplementation(async (token) => ({
      uid: token === "token-b" ? "user-b" : "user-a",
      emailVerified: true,
    }));
    const worker = createWorker(mocks);

    await worker.fetch(uploadRequest("token-a"), env);
    await worker.fetch(uploadRequest("token-b"), env);

    expect(mocks.uploadProfileImage.mock.calls.map((call) => call[1])).toEqual([
      "user-a",
      "user-b",
    ]);
  });

  it("deletes the authenticated user's image", async () => {
    const mocks = defaultMocks();
    const response = await createWorker(mocks).fetch(
      new Request("https://worker.test/v1/profile-image", {
        method: "DELETE",
        headers: { authorization: "Bearer valid-token" },
      }),
      env,
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ deleted: true, status: "deleted" });
    expect(mocks.deleteProfileImage).toHaveBeenCalledWith(env, "user-a");
  });

  it("treats deletion of a missing image as a successful no-op", async () => {
    const mocks = defaultMocks();
    mocks.deleteProfileImage.mockResolvedValueOnce({
      publicId: profilePublicId("user-a"),
      deleted: false,
      notFound: true,
    });
    const response = await createWorker(mocks).fetch(
      new Request("https://worker.test/v1/profile-image", {
        method: "DELETE",
        headers: { authorization: "Bearer valid-token" },
      }),
      env,
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ deleted: false, status: "not_found" });
  });

  it("returns a specific sanitized code for Cloudinary failures", async () => {
    const mocks = defaultMocks();
    const warning = vi.spyOn(console, "warn").mockImplementation(() => undefined);
    mocks.uploadProfileImage.mockRejectedValueOnce(
      new CloudinaryError("CLOUDINARY_INVALID_SIGNATURE", 401),
    );
    const response = await createWorker(mocks).fetch(uploadRequest(), env);
    const body = JSON.stringify(await response.json());

    expect(response.status).toBe(502);
    expect(body).toContain("CLOUDINARY_INVALID_SIGNATURE");
    expect(body).not.toContain(env.CLOUDINARY_API_SECRET);
    expect(body).not.toContain("valid-token");
    expect(warning).toHaveBeenCalledWith(
      "Profile image provider failure:",
      "CLOUDINARY_INVALID_SIGNATURE",
      "upstream_status:",
      401,
    );
    expect(JSON.stringify(warning.mock.calls)).not.toContain(env.CLOUDINARY_API_SECRET);
    expect(JSON.stringify(warning.mock.calls)).not.toContain("valid-token");
  });
});
