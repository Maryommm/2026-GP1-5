import {
  deleteProfileImage,
  PROFILE_IMAGE_FORMAT,
  PROFILE_IMAGE_TRANSFORMATION,
  profilePublicId,
  uploadProfileImage,
} from "../src/cloudinary";
import type { Env, ValidatedImage } from "../src/types";

const env: Env = {
  CLOUDINARY_CLOUD_NAME: "k7otdsln",
  CLOUDINARY_API_KEY: "test-key",
  CLOUDINARY_API_SECRET: "test-secret",
  FIREBASE_PROJECT_ID: "ethmar-95aaf",
  PROFILE_IMAGE_RATE_LIMITER: { limit: async () => ({ success: true }) },
};
const image: ValidatedImage = {
  bytes: new Uint8Array([1, 2, 3]),
  mediaType: "image/png",
  extension: "png",
};

async function sha1Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-1", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

afterEach(() => {
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

describe("Cloudinary profile image operations", () => {
  it("uses the fixed ID and a signed incoming transformation that strips metadata", async () => {
    vi.spyOn(Date, "now").mockReturnValue(1_710_000_000_000);
    let version = 10;
    const fetchMock = vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
      expect(String(input)).toBe(
        "https://api.cloudinary.com/v1_1/k7otdsln/image/upload",
      );
      const form = init?.body as FormData;
      expect(form.getAll("api_key")).toEqual([env.CLOUDINARY_API_KEY]);
      expect(form.get("api_key")).not.toBe(env.CLOUDINARY_API_SECRET);
      expect(form.get("public_id")).toBe("ethmar/profile-images/user-a/profile");
      expect(form.get("overwrite")).toBe("true");
      expect(form.get("invalidate")).toBe("true");
      expect(PROFILE_IMAGE_TRANSFORMATION).toBe(
        "c_limit,h_4096,w_4096/fl_force_strip",
      );
      expect(form.get("transformation")).toBe(
        "c_limit,h_4096,w_4096/fl_force_strip",
      );
      expect(PROFILE_IMAGE_FORMAT).toBe("webp");
      expect(form.get("format")).toBe("webp");
      const canonical = "format=webp&invalidate=true&overwrite=true"
        + "&public_id=ethmar/profile-images/user-a/profile"
        + "&timestamp=1710000000"
        + "&transformation=" + PROFILE_IMAGE_TRANSFORMATION;
      expect(form.get("signature")).toBe(await sha1Hex(canonical + env.CLOUDINARY_API_SECRET));
      version += 1;
      return Response.json({
        resource_type: "image",
        public_id: "ethmar/profile-images/user-a/profile",
        secure_url: "https://res.cloudinary.com/k7otdsln/image/upload/v"
          + version + "/ethmar/profile-images/user-a/profile.webp",
        version,
        format: "webp",
        width: 1,
        height: 1,
        bytes: 3,
      });
    });
    vi.stubGlobal("fetch", fetchMock);

    const first = await uploadProfileImage(env, "user-a", image);
    const replacement = await uploadProfileImage(env, "user-a", image);

    expect(first.version).toBe(11);
    expect(replacement.version).toBe(12);
    expect(replacement.publicId).toBe(first.publicId);
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  it("rejects an upload response that did not store the sanitized WebP result", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => Response.json({
      resource_type: "image",
      public_id: "ethmar/profile-images/user-a/profile",
      secure_url: "https://res.cloudinary.com/k7otdsln/image/upload/v11/ethmar/profile-images/user-a/profile.png",
      version: 11,
      format: "png",
      width: 1,
      height: 1,
      bytes: 3,
    })));

    await expect(uploadProfileImage(env, "user-a", image)).rejects.toMatchObject({
      kind: "CLOUDINARY_INVALID_RESPONSE",
    });
  });

  it.each([
    {
      status: 400,
      headers: [[
        "x-cld-error",
        "Invalid transformation parameter for API key hidden-value",
      ]] as [string, string][],
      body: { error: { message: "Transformation rejected" } },
      kind: "CLOUDINARY_INVALID_TRANSFORMATION",
    },
    {
      status: 401,
      headers: [] as [string, string][],
      body: {
        error: {
          message: "Invalid Signature hidden-value. String to sign contains private data",
        },
      },
      kind: "CLOUDINARY_INVALID_SIGNATURE",
    },
    {
      status: 401,
      headers: [] as [string, string][],
      body: { error: { message: "Unknown API key hidden-value" } },
      kind: "CLOUDINARY_UNKNOWN_API_KEY",
    },
    {
      status: 403,
      headers: [] as [string, string][],
      body: { error: { message: "Request forbidden" } },
      kind: "CLOUDINARY_FORBIDDEN",
    },
  ])("classifies a Cloudinary $status response without exposing its body", async (scenario) => {
    vi.stubGlobal("fetch", vi.fn(async () => Response.json(scenario.body, {
      status: scenario.status,
      headers: scenario.headers,
    })));

    let failure: unknown;
    try {
      await uploadProfileImage(env, "user-a", image);
    } catch (error) {
      failure = error;
    }

    expect(failure).toMatchObject({
      kind: scenario.kind,
      upstreamStatus: scenario.status,
    });
    expect(String(failure)).not.toContain("hidden-value");
    expect(String(failure)).not.toContain("user-a");
    expect(String(failure)).not.toContain(env.CLOUDINARY_API_SECRET);
  });

  it("distinguishes a transport failure from a rejected request", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => {
      throw new Error("network details must remain private");
    }));

    await expect(uploadProfileImage(env, "user-a", image)).rejects.toMatchObject({
      kind: "CLOUDINARY_NETWORK_ERROR",
    });
  });

  it.each([
    { key: "CLOUDINARY_API_KEY=test-key", secret: "test-secret" },
    { key: "\"test-key\"", secret: "test-secret" },
    { key: "test-key", secret: "CLOUDINARY_API_SECRET=test-secret" },
    { key: "test-key", secret: "cloudinary://key:secret@cloud" },
  ])("rejects a wrapped credential before contacting Cloudinary", async (credentials) => {
    const fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);

    await expect(uploadProfileImage({
      ...env,
      CLOUDINARY_API_KEY: credentials.key,
      CLOUDINARY_API_SECRET: credentials.secret,
    }, "user-a", image)).rejects.toMatchObject({ kind: "CONFIGURATION" });
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("performs a real Cloudinary destroy request for the fixed public ID", async () => {
    vi.spyOn(Date, "now").mockReturnValue(1_710_000_000_000);
    const fetchMock = vi.fn(async (_input: RequestInfo | URL, init?: RequestInit) => {
      const form = init?.body as URLSearchParams;
      expect(form.get("public_id")).toBe(profilePublicId("user-a"));
      expect(form.get("invalidate")).toBe("true");
      const canonical = "invalidate=true"
        + "&public_id=ethmar/profile-images/user-a/profile"
        + "&timestamp=1710000000";
      expect(form.get("signature")).toBe(await sha1Hex(canonical + env.CLOUDINARY_API_SECRET));
      return Response.json({ result: "ok" });
    });
    vi.stubGlobal("fetch", fetchMock);

    await expect(deleteProfileImage(env, "user-a")).resolves.toEqual({
      publicId: "ethmar/profile-images/user-a/profile",
      deleted: true,
      notFound: false,
    });
  });

  it("accepts Cloudinary's not-found destroy result", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => Response.json({ result: "not found" })));

    await expect(deleteProfileImage(env, "user-a")).resolves.toEqual({
      publicId: "ethmar/profile-images/user-a/profile",
      deleted: false,
      notFound: true,
    });
  });
});
