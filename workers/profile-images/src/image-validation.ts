import type { SupportedImageType, ValidatedImage } from "./types";

// Set the maximum image and request sizes.
export const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
export const MAX_REQUEST_BYTES = 6 * 1024 * 1024;

// Map supported image types to file extensions.
const TYPE_TO_EXTENSION: Record<SupportedImageType, ValidatedImage["extension"]> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
};

// Define validation errors for invalid upload requests.
export class RequestValidationError extends Error {
  constructor(
    readonly code:
      | "REQUEST_TOO_LARGE"
      | "INVALID_MULTIPART"
      | "FILE_REQUIRED"
      | "UNEXPECTED_FIELD"
      | "EMPTY_FILE"
      | "UNSUPPORTED_IMAGE"
      | "INVALID_IMAGE",
    readonly status: 400 | 413 | 415,
    readonly publicMessage: string,
  ) {
    super(code);
    this.name = "RequestValidationError";
  }
}

function requestTooLarge(): RequestValidationError {
  return new RequestValidationError(
    "REQUEST_TOO_LARGE",
    413,
    "The request is too large. Profile images must be 5 MB or smaller.",
  );
}

// Check the declared request size before reading the body.
export function assertDeclaredRequestSize(request: Request): void {
  const value = request.headers.get("content-length");
  if (value === null) return;
  if (!/^\d+$/.test(value)) {
    throw new RequestValidationError(
      "INVALID_MULTIPART",
      400,
      "The upload request is malformed.",
    );
  }
  if (Number(value) > MAX_REQUEST_BYTES) throw requestTooLarge();
}

// Read the request body without exceeding the upload limit.
async function readRequestBody(request: Request): Promise<Uint8Array> {
  assertDeclaredRequestSize(request);
  if (request.body === null) {
    throw new RequestValidationError(
      "FILE_REQUIRED",
      400,
      "A profile image is required.",
    );
  }

  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;

  // Stop reading if the request exceeds the allowed size.
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > MAX_REQUEST_BYTES) {
      chunks.length = 0;
      try {
        await reader.cancel("Request body exceeds the configured size limit.");
      } catch {
        // Reject the request even if canceling the reader fails.
      }
      throw requestTooLarge();
    }
    chunks.push(value);
  }

  // Combine the received chunks into one byte array.
  const result = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    result.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return result;
}

// Read ASCII characters from image bytes.
function ascii(bytes: Uint8Array, offset: number, length: number): string {
  let result = "";
  for (let i = offset; i < offset + length; i += 1) {
    result += String.fromCharCode(bytes[i]);
  }
  return result;
}

// Read a 32-bit big-endian integer.
function uint32be(bytes: Uint8Array, offset: number): number {
  return (
    bytes[offset] * 0x1000000
    + bytes[offset + 1] * 0x10000
    + bytes[offset + 2] * 0x100
    + bytes[offset + 3]
  );
}

// Read a 32-bit little-endian integer.
function uint32le(bytes: Uint8Array, offset: number): number {
  return (
    bytes[offset]
    + bytes[offset + 1] * 0x100
    + bytes[offset + 2] * 0x10000
    + bytes[offset + 3] * 0x1000000
  );
}

// Check the PNG signature, dimensions, chunks, and final marker.
function isPng(bytes: Uint8Array): boolean {
  const signature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (bytes.length < 45 || !signature.every((byte, i) => bytes[i] === byte)) return false;

  let offset = 8;
  let first = true;
  let foundIend = false;
  while (offset + 12 <= bytes.length) {
    const length = uint32be(bytes, offset);
    const type = ascii(bytes, offset + 4, 4);
    const next = offset + 12 + length;
    if (!Number.isSafeInteger(next) || next > bytes.length) return false;

    if (first) {
      if (type !== "IHDR" || length !== 13) return false;
      const width = uint32be(bytes, offset + 8);
      const height = uint32be(bytes, offset + 12);
      if (width === 0 || height === 0) return false;
      first = false;
    }

    if (type === "IEND") {
      if (length !== 0 || next !== bytes.length) return false;
      foundIend = true;
      break;
    }
    offset = next;
  }
  return foundIend;
}

// JPEG markers that contain image dimensions.
const JPEG_SOF_MARKERS = new Set([
  0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7,
  0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf,
]);

// Check JPEG markers and require valid image dimensions.
function isJpeg(bytes: Uint8Array): boolean {
  if (
    bytes.length < 14
    || bytes[0] !== 0xff
    || bytes[1] !== 0xd8
    || bytes[bytes.length - 2] !== 0xff
    || bytes[bytes.length - 1] !== 0xd9
  ) return false;

  let offset = 2;
  let foundSof = false;
  let foundSos = false;
  // Include the final EOI marker when checking the JPEG.
  while (offset <= bytes.length - 2) {
    if (bytes[offset] !== 0xff) {
      if (!foundSos) return false;
      offset += 1;
      continue;
    }
    while (bytes[offset] === 0xff) offset += 1;
    const marker = bytes[offset];
    offset += 1;

    if (marker === 0x00 || (marker >= 0xd0 && marker <= 0xd7)) continue;
    if (marker === 0xd9) return foundSof && foundSos && offset === bytes.length;
    if (marker === 0x01) continue;
    if (offset + 2 > bytes.length) return false;

    const length = bytes[offset] * 0x100 + bytes[offset + 1];
    if (length < 2 || offset + length > bytes.length) return false;
    if (JPEG_SOF_MARKERS.has(marker)) {
      if (length < 8) return false;
      const height = bytes[offset + 3] * 0x100 + bytes[offset + 4];
      const width = bytes[offset + 5] * 0x100 + bytes[offset + 6];
      if (width === 0 || height === 0) return false;
      foundSof = true;
    }
    if (marker === 0xda) foundSos = true;
    offset += length;
  }
  return false;
}

// Validate RIFF WebP data and its image chunk.
function isWebp(bytes: Uint8Array): boolean {
  if (
    bytes.length < 26
    || ascii(bytes, 0, 4) !== "RIFF"
    || ascii(bytes, 8, 4) !== "WEBP"
    || uint32le(bytes, 4) + 8 !== bytes.length
  ) return false;

  let offset = 12;
  let foundImageChunk = false;
  while (offset + 8 <= bytes.length) {
    const type = ascii(bytes, offset, 4);
    const length = uint32le(bytes, offset + 4);
    const dataOffset = offset + 8;
    const next = dataOffset + length + (length % 2);
    if (!Number.isSafeInteger(next) || next > bytes.length) return false;

    if (type === "VP8X") {
      if (length < 10) return false;
      const width = 1 + bytes[dataOffset + 4]
        + bytes[dataOffset + 5] * 0x100
        + bytes[dataOffset + 6] * 0x10000;
      const height = 1 + bytes[dataOffset + 7]
        + bytes[dataOffset + 8] * 0x100
        + bytes[dataOffset + 9] * 0x10000;
      if (width <= 0 || height <= 0) return false;
      foundImageChunk = true;
    } else if (type === "VP8L") {
      if (length < 5 || bytes[dataOffset] !== 0x2f) return false;
      const bits = (
        bytes[dataOffset + 1]
        | bytes[dataOffset + 2] << 8
        | bytes[dataOffset + 3] << 16
        | bytes[dataOffset + 4] << 24
      ) >>> 0;
      const width = (bits & 0x3fff) + 1;
      const height = ((bits >>> 14) & 0x3fff) + 1;
      if (width <= 0 || height <= 0) return false;
      foundImageChunk = true;
    } else if (type === "VP8 ") {
      if (
        length < 10
        || bytes[dataOffset + 3] !== 0x9d
        || bytes[dataOffset + 4] !== 0x01
        || bytes[dataOffset + 5] !== 0x2a
      ) return false;
      const width = (bytes[dataOffset + 6] + bytes[dataOffset + 7] * 0x100) & 0x3fff;
      const height = (bytes[dataOffset + 8] + bytes[dataOffset + 9] * 0x100) & 0x3fff;
      if (width === 0 || height === 0) return false;
      foundImageChunk = true;
    }
    offset = next;
  }
  return foundImageChunk && offset === bytes.length;
}

// Detect the actual image type from its content.
function actualType(bytes: Uint8Array): SupportedImageType | null {
  if (isJpeg(bytes)) return "image/jpeg";
  if (isPng(bytes)) return "image/png";
  if (isWebp(bytes)) return "image/webp";
  return null;
}

// Accept exactly one valid image from the multipart request.
export async function parseProfileImageRequest(request: Request): Promise<ValidatedImage> {
  const contentType = request.headers.get("content-type") ?? "";
  if (!contentType.toLowerCase().startsWith("multipart/form-data;")) {
    throw new RequestValidationError(
      "INVALID_MULTIPART",
      400,
      "The upload must use multipart/form-data.",
    );
  }

  // Read and parse the multipart request.
  const body = await readRequestBody(request);
  let form: FormData;
  try {
    const bodyBuffer = Uint8Array.from(body).buffer;
    form = await new Response(bodyBuffer, { headers: { "content-type": contentType } }).formData();
  } catch {
    throw new RequestValidationError(
      "INVALID_MULTIPART",
      400,
      "The upload request is malformed.",
    );
  }

  const entries: Array<[string, FormDataEntryValue]> = [];
  form.forEach((value, key) => {
    entries.push([key, value]);
  });

  // Reject unexpected fields and multiple files.
  if (entries.some(([key]) => key !== "file")) {
    throw new RequestValidationError(
      "UNEXPECTED_FIELD",
      400,
      "Only the profile image file may be submitted.",
    );
  }
  if (entries.length !== 1 || entries[0][0] !== "file") {
    throw new RequestValidationError(
      "FILE_REQUIRED",
      400,
      "Exactly one profile image is required.",
    );
  }
  const value = entries[0][1];
  if (typeof value === "string") {
    throw new RequestValidationError(
      "FILE_REQUIRED",
      400,
      "Exactly one profile image is required.",
    );
  }

  // Reject empty or oversized image files.
  const file = value;
  if (file.size === 0) {
    throw new RequestValidationError("EMPTY_FILE", 400, "The profile image is empty.");
  }
  if (file.size > MAX_IMAGE_BYTES) throw requestTooLarge();

  // Validate the image using its bytes, not only its declared type.
  const bytes = new Uint8Array(await file.arrayBuffer());
  const detectedType = actualType(bytes);
  if (detectedType === null) {
    const declaredType = file.type.toLowerCase() as SupportedImageType;
    if (!(declaredType in TYPE_TO_EXTENSION)) {
      throw new RequestValidationError(
        "UNSUPPORTED_IMAGE",
        415,
        "Only JPEG, PNG, and WebP images are accepted.",
      );
    }
    throw new RequestValidationError(
      "INVALID_IMAGE",
      415,
      "The uploaded file is not a valid JPEG, PNG, or WebP image.",
    );
  }

  // Return the validated image data for uploading.
  return {
    bytes,
    mediaType: detectedType,
    extension: TYPE_TO_EXTENSION[detectedType],
  };
}