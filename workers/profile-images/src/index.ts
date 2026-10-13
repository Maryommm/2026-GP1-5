import { deleteProfileImage, CloudinaryError, uploadProfileImage } from "./cloudinary";
import {
  AuthenticationError,
  readBearerToken,
  verifyFirebaseIdToken,
} from "./firebase-auth";
import {
  assertDeclaredRequestSize,
  parseProfileImageRequest,
  RequestValidationError,
} from "./image-validation";
import { errorResponse, jsonResponse } from "./responses";
import type { Env, WorkerDependencies } from "./types";

const PROFILE_IMAGE_PATH = "/v1/profile-image";

const defaultDependencies: WorkerDependencies = {
  verifyToken: verifyFirebaseIdToken,
  uploadProfileImage,
  deleteProfileImage,
};

export function createWorker(overrides: Partial<WorkerDependencies> = {}) {
  const dependencies: WorkerDependencies = { ...defaultDependencies, ...overrides };

  return {
    async fetch(request: Request, env: Env): Promise<Response> {
      const url = new URL(request.url);
      if (url.pathname !== PROFILE_IMAGE_PATH) {
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
        if (request.method === "POST") assertDeclaredRequestSize(request);
        const token = readBearerToken(request);
        const user = await dependencies.verifyToken(token, env);
        const rateLimit = await env.PROFILE_IMAGE_RATE_LIMITER.limit({ key: user.uid });
        if (!rateLimit.success) {
          return errorResponse(
            429,
            "RATE_LIMIT_EXCEEDED",
            "Too many profile image operations. Please try again later.",
            { "retry-after": "60" },
          );
        }

        if (request.method === "POST") {
          const image = await parseProfileImageRequest(request);
          const uploaded = await dependencies.uploadProfileImage(env, user.uid, image);
          return jsonResponse({ image: uploaded });
        }

        if (request.body !== null) {
          return errorResponse(
            400,
            "UNEXPECTED_BODY",
            "The delete request must not contain a body.",
          );
        }
        const deleted = await dependencies.deleteProfileImage(env, user.uid);
        return jsonResponse({
          deleted: deleted.deleted,
          status: deleted.notFound ? "not_found" : "deleted",
        });
      } catch (error) {
        if (error instanceof AuthenticationError) {
          return errorResponse(error.status, error.code, error.publicMessage);
        }
        if (error instanceof RequestValidationError) {
          return errorResponse(error.status, error.code, error.publicMessage);
        }
        if (error instanceof CloudinaryError) {
          // Log only our fixed diagnostic category. Never log the provider
          // response, signed parameters, Firebase token, UID, or image data.
          console.warn(
            "Profile image provider failure:",
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
