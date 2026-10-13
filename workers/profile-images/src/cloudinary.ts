import type {
  DeletedProfileImage,
  Env,
  UploadedProfileImage,
  ValidatedImage,
} from "./types";

export type CloudinaryFailureKind =
  | "CONFIGURATION"
  | "CLOUDINARY_NETWORK_ERROR"
  | "CLOUDINARY_INVALID_SIGNATURE"
  | "CLOUDINARY_INVALID_TIMESTAMP"
  | "CLOUDINARY_UNKNOWN_API_KEY"
  | "CLOUDINARY_INVALID_API_KEY"
  | "CLOUDINARY_API_KEY_DISABLED"
  | "CLOUDINARY_INVALID_TRANSFORMATION"
  | "CLOUDINARY_INVALID_FILE"
  | "CLOUDINARY_CLOUD_DISABLED"
  | "CLOUDINARY_BAD_REQUEST"
  | "CLOUDINARY_AUTH_FAILED"
  | "CLOUDINARY_FORBIDDEN"
  | "CLOUDINARY_RATE_LIMITED"
  | "CLOUDINARY_UPSTREAM_ERROR"
  | "CLOUDINARY_REQUEST_FAILED"
  | "CLOUDINARY_INVALID_RESPONSE";

export class CloudinaryError extends Error {
  constructor(
    readonly kind: CloudinaryFailureKind,
    readonly upstreamStatus?: number,
  ) {
    super(kind);
    this.name = "CloudinaryError";
  }
}

interface CloudinaryConfig {
  cloudName: string;
  apiKey: string;
  apiSecret: string;
}

interface CloudinaryUploadResponse {
  public_id?: unknown;
  secure_url?: unknown;
  version?: unknown;
  format?: unknown;
  width?: unknown;
  height?: unknown;
  bytes?: unknown;
  resource_type?: unknown;
}

interface CloudinaryDestroyResponse {
  result?: unknown;
}

export const PROFILE_IMAGE_TRANSFORMATION = "c_limit,h_4096,w_4096/fl_force_strip";
export const PROFILE_IMAGE_FORMAT = "webp";
const MAX_CLOUDINARY_ERROR_BYTES = 8 * 1024;

function configFrom(env: Env): CloudinaryConfig {
  const cloudName = env.CLOUDINARY_CLOUD_NAME?.trim();
  const apiKey = env.CLOUDINARY_API_KEY?.trim();
  const apiSecret = env.CLOUDINARY_API_SECRET?.trim();
  if (
    !cloudName
    || !apiKey
    || !apiSecret
    || !/^[A-Za-z0-9_-]+$/.test(cloudName)
    || looksLikeWrappedCredential(apiKey, "CLOUDINARY_API_KEY")
    || looksLikeWrappedCredential(apiSecret, "CLOUDINARY_API_SECRET")
  ) {
    throw new CloudinaryError("CONFIGURATION");
  }
  return { cloudName, apiKey, apiSecret };
}

function looksLikeWrappedCredential(value: string, variableName: string): boolean {
  const lower = value.toLowerCase();
  return lower.startsWith(variableName.toLowerCase() + "=")
    || lower.startsWith("cloudinary://")
    || (value.startsWith('"') && value.endsWith('"'))
    || (value.startsWith("'") && value.endsWith("'"));
}

async function sha1Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-1", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function sign(parameters: Record<string, string>, apiSecret: string): Promise<string> {
  const canonical = Object.keys(parameters)
    .sort()
    .map((key) => key + "=" + parameters[key])
    .join("&");
  return sha1Hex(canonical + apiSecret);
}

export function profilePublicId(uid: string): string {
  return "ethmar/profile-images/" + uid + "/profile";
}

async function safeJson<T>(response: Response): Promise<T> {
  try {
    return await response.json() as T;
  } catch {
    throw new CloudinaryError("CLOUDINARY_INVALID_RESPONSE");
  }
}

async function readBoundedErrorText(response: Response): Promise<string> {
  if (response.body === null) return "";

  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      if (total + value.byteLength > MAX_CLOUDINARY_ERROR_BYTES) {
        await reader.cancel();
        break;
      }
      chunks.push(value);
      total += value.byteLength;
    }
  } catch {
    return "";
  }

  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder().decode(bytes);
}

function messageFromErrorJson(text: string): string {
  try {
    const body = JSON.parse(text) as { error?: { message?: unknown } };
    return typeof body.error?.message === "string" ? body.error.message : "";
  } catch {
    return "";
  }
}

function classifyCloudinaryDiagnostic(
  status: number,
  diagnostic: string,
): CloudinaryFailureKind {
  const normalized = diagnostic.toLowerCase();
  if (
    normalized.includes("invalid signature")
    || normalized.includes("signature mismatch")
    || normalized.includes("api secret mismatch")
  ) {
    return "CLOUDINARY_INVALID_SIGNATURE";
  }
  if (
    normalized.includes("timestamp")
    && /(invalid|expired|too old|future|difference)/.test(normalized)
  ) {
    return "CLOUDINARY_INVALID_TIMESTAMP";
  }
  if (normalized.includes("cloud") && normalized.includes("disabled")) {
    return "CLOUDINARY_CLOUD_DISABLED";
  }
  if (normalized.includes("transformation") || normalized.includes("force_strip")) {
    return "CLOUDINARY_INVALID_TRANSFORMATION";
  }
  if (
    normalized.includes("invalid image")
    || normalized.includes("unsupported image")
    || normalized.includes("invalid file")
  ) {
    return "CLOUDINARY_INVALID_FILE";
  }
  if (/\bunknown api[ _-]?key\b/.test(normalized)) {
    return "CLOUDINARY_UNKNOWN_API_KEY";
  }
  if (
    /\b(?:disabled|deactivated|revoked) api[ _-]?key\b/.test(normalized)
    || /\bapi[ _-]?key\b.{0,40}\b(?:disabled|deactivated|revoked)\b/.test(normalized)
  ) {
    return "CLOUDINARY_API_KEY_DISABLED";
  }
  if (
    /\binvalid api[ _-]?key\b/.test(normalized)
    || /\bapi[ _-]?key\b.{0,40}\b(?:invalid|not found)\b/.test(normalized)
  ) {
    return "CLOUDINARY_INVALID_API_KEY";
  }

  if (status === 400) return "CLOUDINARY_BAD_REQUEST";
  if (status === 401) return "CLOUDINARY_AUTH_FAILED";
  if (status === 403) return "CLOUDINARY_FORBIDDEN";
  if (status === 429) return "CLOUDINARY_RATE_LIMITED";
  if (status >= 500) return "CLOUDINARY_UPSTREAM_ERROR";
  return "CLOUDINARY_REQUEST_FAILED";
}

async function cloudinaryHttpError(response: Response): Promise<CloudinaryError> {
  // Cloudinary documents X-Cld-Error for diagnostics. Its raw value and the
  // response body may contain signed parameters, so they are classified only.
  const header = response.headers.get("x-cld-error") ?? "";
  const bodyText = await readBoundedErrorText(response);
  const jsonMessage = messageFromErrorJson(bodyText);
  return new CloudinaryError(
    classifyCloudinaryDiagnostic(response.status, header + "\n" + jsonMessage),
    response.status,
  );
}

function isExpectedUploadUrl(
  value: string,
  cloudName: string,
  publicId: string,
  version: number,
): boolean {
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    return false;
  }
  if (
    url.protocol !== "https:"
    || url.hostname !== "res.cloudinary.com"
    || url.search !== ""
    || url.hash !== ""
  ) {
    return false;
  }

  const segments = url.pathname.split("/").filter(Boolean);
  if (
    segments.length < 5
    || segments[0] !== cloudName
    || segments[1] !== "image"
    || segments[2] !== "upload"
  ) {
    return false;
  }
  const versionIndex = segments.indexOf("v" + version, 3);
  return versionIndex >= 3
    && segments.slice(versionIndex + 1).join("/") === publicId + "." + PROFILE_IMAGE_FORMAT;
}

export async function uploadProfileImage(
  env: Env,
  uid: string,
  image: ValidatedImage,
): Promise<UploadedProfileImage> {
  const config = configFrom(env);
  const publicId = profilePublicId(uid);
  const timestamp = Math.floor(Date.now() / 1000);
  const signedParameters = {
    format: PROFILE_IMAGE_FORMAT,
    invalidate: "true",
    overwrite: "true",
    public_id: publicId,
    timestamp: String(timestamp),
    transformation: PROFILE_IMAGE_TRANSFORMATION,
  };
  const signature = await sign(signedParameters, config.apiSecret);

  const form = new FormData();
  const imageBuffer = Uint8Array.from(image.bytes).buffer;
  form.set("file", new Blob([imageBuffer], { type: image.mediaType }), "profile." + image.extension);
  form.set("api_key", config.apiKey);
  for (const [name, value] of Object.entries(signedParameters)) form.set(name, value);
  form.set("signature", signature);

  let response: Response;
  try {
    response = await fetch(
      "https://api.cloudinary.com/v1_1/" + encodeURIComponent(config.cloudName) + "/image/upload",
      { method: "POST", body: form },
    );
  } catch {
    throw new CloudinaryError("CLOUDINARY_NETWORK_ERROR");
  }
  if (!response.ok) throw await cloudinaryHttpError(response);

  const data = await safeJson<CloudinaryUploadResponse>(response);
  if (
    data.resource_type !== "image"
    || data.public_id !== publicId
    || typeof data.secure_url !== "string"
    || typeof data.version !== "number"
    || !Number.isSafeInteger(data.version)
    || !isExpectedUploadUrl(data.secure_url, config.cloudName, publicId, data.version)
    || data.format !== PROFILE_IMAGE_FORMAT
    || typeof data.width !== "number"
    || !Number.isSafeInteger(data.width)
    || data.width <= 0
    || data.width > 4096
    || typeof data.height !== "number"
    || !Number.isSafeInteger(data.height)
    || data.height <= 0
    || data.height > 4096
    || typeof data.bytes !== "number"
    || !Number.isSafeInteger(data.bytes)
    || data.bytes <= 0
    || data.bytes > 5 * 1024 * 1024
  ) {
    throw new CloudinaryError("CLOUDINARY_INVALID_RESPONSE");
  }

  return {
    publicId,
    secureUrl: data.secure_url,
    version: data.version,
    format: data.format,
    width: data.width,
    height: data.height,
    bytes: data.bytes,
  };
}

export async function deleteProfileImage(env: Env, uid: string): Promise<DeletedProfileImage> {
  const config = configFrom(env);
  const publicId = profilePublicId(uid);
  const timestamp = Math.floor(Date.now() / 1000);
  const signedParameters = {
    invalidate: "true",
    public_id: publicId,
    timestamp: String(timestamp),
  };
  const signature = await sign(signedParameters, config.apiSecret);

  const form = new URLSearchParams();
  form.set("api_key", config.apiKey);
  for (const [name, value] of Object.entries(signedParameters)) form.set(name, value);
  form.set("signature", signature);

  let response: Response;
  try {
    response = await fetch(
      "https://api.cloudinary.com/v1_1/" + encodeURIComponent(config.cloudName) + "/image/destroy",
      {
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: form,
      },
    );
  } catch {
    throw new CloudinaryError("CLOUDINARY_NETWORK_ERROR");
  }
  if (!response.ok) throw await cloudinaryHttpError(response);

  const data = await safeJson<CloudinaryDestroyResponse>(response);
  if (data.result === "ok") return { publicId, deleted: true, notFound: false };
  if (data.result === "not found" || data.result === "not_found") {
    return { publicId, deleted: false, notFound: true };
  }
  throw new CloudinaryError("CLOUDINARY_INVALID_RESPONSE");
}
