import {
  CloudinaryError,
  deleteGrowthPhoto,
  deletePlantGrowthPhotos,
  deleteProfileImage,
  uploadGrowthPhoto,
  uploadProfileImage,
} from "./cloudinary";
import {
  AuthenticationError,
  readBearerToken,
  verifyFirebaseIdToken,
} from "./firebase-auth";
import {
  assertDeclaredRequestSize,
  isValidGrowthId,
  parseGrowthPhotoRequest,
  parseProfileImageRequest,
  RequestValidationError,
} from "./image-validation";
import { errorResponse, jsonResponse } from "./responses";
import type { Env, WorkerDependencies } from "./types";

const PROFILE_IMAGE_PATH = "/v1/profile-image";
const GROWTH_PHOTO_PATH = "/v1/plant-growth";

type Route = "profile" | "growth";

// Treat transport-level empty streams as bodyless requests.
async function hasBodyBytes(request: Request): Promise<boolean> {
  const body = request.body;
  if (body === null) return false;

  const reader = body.getReader();
  try {
    while (true) {
      const chunk = await reader.read();
      if (chunk.done) return false;
      if (chunk.value.byteLength > 0) return true;
    }
  } finally {
    await reader.cancel().catch(() => undefined);
    reader.releaseLock();
  }
}

function unexpectedBody(): Response {
  return errorResponse(
    400,
    "UNEXPECTED_BODY",
    "The delete request must not contain a body.",
  );
}

// Set the default authentication and image service dependencies.
const defaultDependencies: WorkerDependencies = {
  verifyToken: verifyFirebaseIdToken,
  uploadProfileImage,
  deleteProfileImage,
  uploadGrowthPhoto,
  deleteGrowthPhoto,
  deletePlantGrowthPhotos,
};

// Create the authenticated image API handler.
export function createWorker(overrides: Partial<WorkerDependencies> = {}) {
  const dependencies: WorkerDependencies = { ...defaultDependencies, ...overrides };

  // The user's profile image: one fixed image per user.
  async function handleProfile(request: Request, env: Env, uid: string): Promise<Response> {
    // Validate and upload the user's profile image.
    if (request.method === "POST") {
      const image = await parseProfileImageRequest(request);
      const uploaded = await dependencies.uploadProfileImage(env, uid, image);
      return jsonResponse({ image: uploaded });
    }

    // Reject delete requests that contain actual body bytes.
    if (await hasBodyBytes(request)) return unexpectedBody();

    // Delete the authenticated user's profile image.
    const deleted = await dependencies.deleteProfileImage(env, uid);
    return jsonResponse({
      deleted: deleted.deleted,
      status: deleted.notFound ? "not_found" : "deleted",
    });
  }

  // Growth photos: one per growth entry, in a folder per plant.
  //   POST   multipart: file, plantId, entryId
  //   DELETE ?plantId=…&entryId=…   one photo
  //   DELETE ?plantId=…             every photo of the plant
  async function handleGrowth(
    request: Request,
    url: URL,
    env: Env,
    uid: string,
  ): Promise<Response> {
    if (request.method === "POST") {
      const { image, plantId, entryId } = await parseGrowthPhotoRequest(request);
      const uploaded = await dependencies.uploadGrowthPhoto(env, uid, plantId, entryId, image);
      return jsonResponse({ image: uploaded });
    }

    if (await hasBodyBytes(request)) return unexpectedBody();

    // Only plantId and an optional entryId, each at most once.
    const keys = [...url.searchParams.keys()];
    const plantIds = url.searchParams.getAll("plantId");
    const entryIds = url.searchParams.getAll("entryId");
    if (
      keys.some((key) => key !== "plantId" && key !== "entryId")
      || plantIds.length !== 1
      || entryIds.length > 1
      || !isValidGrowthId(plantIds[0])
      || (entryIds.length === 1 && !isValidGrowthId(entryIds[0]))
    ) {
      return errorResponse(400, "INVALID_ID", "The plant or growth entry ID is invalid.");
    }

    if (entryIds.length === 0) {
      const result = await dependencies.deletePlantGrowthPhotos(env, uid, plantIds[0]);
      return jsonResponse({ deletedPhotos: result.deleted });
    }
    const deleted = await dependencies.deleteGrowthPhoto(env, uid, plantIds[0], entryIds[0]);
    return jsonResponse({
      deleted: deleted.deleted,
      status: deleted.notFound ? "not_found" : "deleted",
    });
  }

  return {
    async fetch(request: Request, env: Env): Promise<Response> {
      const url = new URL(request.url);

      // Accept requests only for the image endpoints.
      const route: Route | null = url.pathname === PROFILE_IMAGE_PATH
        ? "profile"
        : url.pathname === GROWTH_PHOTO_PATH ? "growth" : null;
      if (route === null) {
        return errorResponse(404, "NOT_FOUND", "The requested endpoint does not exist.");
      }
      if (request.method !== "POST" && request.method !== "DELETE") {
        return errorResponse(
          405,
          "METHOD_NOT_ALLOWED",
          "Only POST and DELETE are allowed for this endpoint.",
        );
      }

      try {
        // Authenticate the Firebase user before accessing image services.
        if (request.method === "POST") assertDeclaredRequestSize(request);
        const token = readBearerToken(request);
        const user = await dependencies.verifyToken(token, env);

        // Limit image operations separately for each authenticated user,
        // with a separate budget for growth photos.
        const rateLimit = await env.PROFILE_IMAGE_RATE_LIMITER.limit({
          key: route === "profile" ? user.uid : "growth:" + user.uid,
        });
        if (!rateLimit.success) {
          return errorResponse(
            429,
            "RATE_LIMIT_EXCEEDED",
            "Too many image operations. Please try again later.",
            { "retry-after": "60" },
          );
        }

        return route === "profile"
          ? await handleProfile(request, env, user.uid)
          : await handleGrowth(request, url, env, user.uid);
      } catch (error) {
        // Return safe error responses without exposing sensitive details.
        if (error instanceof AuthenticationError) {
          return errorResponse(error.status, error.code, error.publicMessage);
        }
        if (error instanceof RequestValidationError) {
          return errorResponse(error.status, error.code, error.publicMessage);
        }
        if (error instanceof CloudinaryError) {
          // Log only safe error categories, never tokens, IDs, or image data.
          console.warn(
            route === "profile"
              ? "Profile image provider failure:"
              : "Growth photo provider failure:",
            error.kind,
            "upstream_status:",
            error.upstreamStatus ?? "none",
          );
          if (error.kind === "CONFIGURATION") {
            return errorResponse(
              500,
              "SERVICE_NOT_CONFIGURED",
              "The image service is not configured.",
            );
          }
          return errorResponse(
            502,
            error.kind,
            "The image service is temporarily unavailable.",
          );
        }
        return errorResponse(500, "INTERNAL_ERROR", "The request could not be completed.");
      }
    },
  };
}

export default createWorker();
