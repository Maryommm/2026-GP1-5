import { CloudinaryError, growthPublicId, profilePublicId } from "../src/cloudinary";
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
  const uploadGrowthPhoto = vi.fn<WorkerDependencies["uploadGrowthPhoto"]>(
    async (_env, uid, plantId, entryId) => ({
      ...uploaded(uid, 1),
      publicId: growthPublicId(uid, plantId, entryId),
    }),
  );
  const deleteGrowthPhoto = vi.fn<WorkerDependencies["deleteGrowthPhoto"]>(
    async (_env, uid, plantId, entryId) => ({
      publicId: growthPublicId(uid, plantId, entryId),
      deleted: true,
      notFound: false,
    }),
  );
  const deletePlantGrowthPhotos = vi.fn<WorkerDependencies["deletePlantGrowthPhotos"]>(
    async () => ({ deleted: 2 }),
  );
  return {
    verifyToken,
    uploadProfileImage,
    deleteProfileImage,
    uploadGrowthPhoto,
    deleteGrowthPhoto,
    deletePlantGrowthPhotos,
  };
}

function growthUpload(fields: Array<[string, string]>, token = "valid-token"): Request {
  const form = new FormData();
  form.set("file", new File([ONE_PIXEL_PNG], "growth.png", { type: "image/png" }));
  for (const [name, value] of fields) form.append(name, value);
  return new Request("https://worker.test/v1/plant-growth", {
    method: "POST",
    headers: { authorization: "Bearer " + token },
    body: form,
  });
}

function growthDelete(query: string): Request {
  return new Request("https://worker.test/v1/plant-growth" + query, {
    method: "DELETE",
    headers: { authorization: "Bearer valid-token" },
  });
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

  it("accepts a zero-byte DELETE body stream", async () => {
    const mocks = defaultMocks();
    const request = new Request("https://worker.test/v1/profile-image", {
      method: "DELETE",
      headers: { authorization: "Bearer valid-token" },
      body: new Uint8Array(0),
    });

    expect(request.body).not.toBeNull();
    const response = await createWorker(mocks).fetch(request, env);

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ deleted: true, status: "deleted" });
    expect(mocks.deleteProfileImage).toHaveBeenCalledWith(env, "user-a");
  });

  it("rejects a DELETE request containing body bytes", async () => {
    const mocks = defaultMocks();
    const response = await createWorker(mocks).fetch(
      new Request("https://worker.test/v1/profile-image", {
        method: "DELETE",
        headers: { authorization: "Bearer valid-token" },
        body: "unexpected",
      }),
      env,
    );

    expect(response.status).toBe(400);
    expect(await response.json()).toEqual({
      error: {
        code: "UNEXPECTED_BODY",
        message: "The delete request must not contain a body.",
      },
    });
    expect(mocks.deleteProfileImage).not.toHaveBeenCalled();
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

describe("growth photo endpoint", () => {
  beforeEach(() => vi.restoreAllMocks());

  it("uploads into the verified user's folder for that plant and entry", async () => {
    const mocks = defaultMocks();
    const response = await createWorker(mocks).fetch(
      growthUpload([["plantId", "plant-1"], ["entryId", "entry-1"]]),
      env,
    );

    expect(response.status).toBe(200);
    const body = await response.json() as { image: UploadedProfileImage };
    expect(body.image.publicId).toBe("ethmar/plant-growth/user-a/plant-1/entry-1");
    expect(mocks.uploadGrowthPhoto.mock.calls[0].slice(1, 4))
      .toEqual(["user-a", "plant-1", "entry-1"]);
    expect(mocks.uploadProfileImage).not.toHaveBeenCalled();
  });

  it("needs a login, like the profile image", async () => {
    const mocks = defaultMocks();
    const response = await createWorker(mocks).fetch(
      growthUpload([["plantId", "plant-1"], ["entryId", "entry-1"]], "bad-token"),
      env,
    );

    expect(response.status).toBe(401);
    expect(mocks.uploadGrowthPhoto).not.toHaveBeenCalled();
  });

  it.each([
    { case: "a missing entry ID", fields: [["plantId", "plant-1"]] },
    { case: "a path in an ID", fields: [["plantId", "../user-b"], ["entryId", "e"]] },
    { case: "a slash in an ID", fields: [["plantId", "p"], ["entryId", "a/b"]] },
    { case: "a repeated ID", fields: [["plantId", "p"], ["plantId", "q"], ["entryId", "e"]] },
  ])("rejects $case", async ({ fields }) => {
    const mocks = defaultMocks();
    const response = await createWorker(mocks).fetch(
      growthUpload(fields as Array<[string, string]>),
      env,
    );

    expect(response.status).toBe(400);
    expect(await response.json()).toMatchObject({ error: { code: "INVALID_ID" } });
    expect(mocks.uploadGrowthPhoto).not.toHaveBeenCalled();
  });

  it("rejects a client-provided UID or public ID", async () => {
    for (const field of ["uid", "public_id"]) {
      const mocks = defaultMocks();
      const response = await createWorker(mocks).fetch(
        growthUpload([["plantId", "p"], ["entryId", "e"], [field, "user-b"]]),
        env,
      );
      expect(response.status).toBe(400);
      expect(await response.json()).toMatchObject({ error: { code: "UNEXPECTED_FIELD" } });
      expect(mocks.uploadGrowthPhoto).not.toHaveBeenCalled();
    }
  });

  it("has its own rate limit budget, apart from the profile image", async () => {
    const mocks = defaultMocks();
    const limit = vi.fn(async () => ({ success: true }));
    await createWorker(mocks).fetch(
      growthUpload([["plantId", "p"], ["entryId", "e"]]),
      { ...env, PROFILE_IMAGE_RATE_LIMITER: { limit } },
    );

    expect(limit).toHaveBeenCalledWith({ key: "growth:user-a" });
  });

  it("deletes one entry's photo", async () => {
    const mocks = defaultMocks();
    const response = await createWorker(mocks).fetch(
      growthDelete("?plantId=plant-1&entryId=entry-1"),
      env,
    );

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ deleted: true, status: "deleted" });
    expect(mocks.deleteGrowthPhoto).toHaveBeenCalledWith(env, "user-a", "plant-1", "entry-1");
    expect(mocks.deletePlantGrowthPhotos).not.toHaveBeenCalled();
  });

  it("deletes every photo of a plant", async () => {
    const mocks = defaultMocks();
    const response = await createWorker(mocks).fetch(growthDelete("?plantId=plant-1"), env);

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ deletedPhotos: 2 });
    expect(mocks.deletePlantGrowthPhotos).toHaveBeenCalledWith(env, "user-a", "plant-1");
  });

  it.each(["", "?entryId=e", "?plantId=a/b", "?plantId=p&folder=x", "?plantId=p&plantId=q"])(
    "rejects the delete query %j",
    async (query) => {
      const mocks = defaultMocks();
      const response = await createWorker(mocks).fetch(growthDelete(query), env);

      expect(response.status).toBe(400);
      expect(await response.json()).toMatchObject({ error: { code: "INVALID_ID" } });
      expect(mocks.deleteGrowthPhoto).not.toHaveBeenCalled();
      expect(mocks.deletePlantGrowthPhotos).not.toHaveBeenCalled();
    },
  );
});
