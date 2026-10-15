import {
  MAX_IMAGE_BYTES,
  MAX_REQUEST_BYTES,
  parseProfileImageRequest,
  RequestValidationError,
} from "../src/image-validation";

const ONE_PIXEL_PNG = Uint8Array.from(
  atob("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="),
  (character) => character.charCodeAt(0),
);

// Covers the final JPEG marker that caused an earlier parser bug.
const ONE_PIXEL_JPEG = Uint8Array.from(
  atob(
    "/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAMCAgMCAgMDAwMEAwMEBQgFBQQEBQoHBwYI"
      + "DAoMDAsKCwsNDhIQDQ4RDgsLEBYQERMUFRUVDA8XGBYUGBIUFRT/2wBDAQMEBAUEBQkF"
      + "BQkUDQsNFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQU"
      + "FBQUFBT/wAARCAABAAEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBg"
      + "cICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0"
      + "KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZW"
      + "ZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxM"
      + "XGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQ"
      + "AAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQ"
      + "dhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSE"
      + "lKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqK"
      + "mqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADA"
      + "MBAAIRAxEAPwD50ooor8MP9Uz/2Q==",
  ),
  (character) => character.charCodeAt(0),
);

const ONE_PIXEL_WEBP = Uint8Array.from(
  atob("UklGRiIAAABXRUJQVlA4IBYAAAAwAQCdASoBAAEADsD+JaQAA3AAAAAA"),
  (character) => character.charCodeAt(0),
);

function requestWith(form: FormData): Request {
  return new Request("https://worker.test/v1/profile-image", {
    method: "POST",
    body: form,
  });
}

async function expectValidationCode(promise: Promise<unknown>, code: string): Promise<void> {
  try {
    await promise;
    throw new Error("Expected validation to fail.");
  } catch (error) {
    expect(error).toBeInstanceOf(RequestValidationError);
    expect((error as RequestValidationError).code).toBe(code);
  }
}

describe("profile image validation", () => {
  it("accepts a structurally valid PNG", async () => {
    const form = new FormData();
    form.set("file", new File([ONE_PIXEL_PNG], "profile.png", { type: "image/png" }));

    const image = await parseProfileImageRequest(requestWith(form));

    expect(image.mediaType).toBe("image/png");
    expect(image.extension).toBe("png");
    expect(image.bytes).toEqual(ONE_PIXEL_PNG);
  });

  it("accepts a valid JPEG with an extensionless Android cache name", async () => {
    const form = new FormData();
    form.set(
      "file",
      new File([ONE_PIXEL_JPEG], "image_picker_cache", { type: "application/octet-stream" }),
    );

    const image = await parseProfileImageRequest(requestWith(form));

    expect(image.mediaType).toBe("image/jpeg");
    expect(image.extension).toBe("jpg");
    expect(image.bytes).toEqual(ONE_PIXEL_JPEG);
  });

  it("accepts WebP content even when the temporary name says PNG", async () => {
    const form = new FormData();
    form.set("file", new File([ONE_PIXEL_WEBP], "screenshot.png", { type: "image/png" }));

    const image = await parseProfileImageRequest(requestWith(form));

    expect(image.mediaType).toBe("image/webp");
    expect(image.extension).toBe("webp");
    expect(image.bytes).toEqual(ONE_PIXEL_WEBP);
  });

  it("rejects an unsupported declared type", async () => {
    const form = new FormData();
    form.set("file", new File(["GIF89a"], "profile.gif", { type: "image/gif" }));

    await expectValidationCode(
      parseProfileImageRequest(requestWith(form)),
      "UNSUPPORTED_IMAGE",
    );
  });

  it("rejects content that only claims to be a PNG", async () => {
    const form = new FormData();
    form.set("file", new File(["not an image"], "profile.png", { type: "image/png" }));

    await expectValidationCode(parseProfileImageRequest(requestWith(form)), "INVALID_IMAGE");
  });

  it("rejects a file larger than 5 MB", async () => {
    const form = new FormData();
    form.set(
      "file",
      new File([new Uint8Array(MAX_IMAGE_BYTES + 1)], "large.png", { type: "image/png" }),
    );

    await expectValidationCode(
      parseProfileImageRequest(requestWith(form)),
      "REQUEST_TOO_LARGE",
    );
  });

  it("rejects a complete multipart request larger than 6 MB", async () => {
    const request = {
      headers: new Headers({
        "content-type": "multipart/form-data; boundary=test",
        "content-length": String(MAX_REQUEST_BYTES + 1),
      }),
      body: null,
    } as Request;

    await expectValidationCode(
      parseProfileImageRequest(request),
      "REQUEST_TOO_LARGE",
    );
  });

  it("cancels the request stream immediately after it exceeds 6 MB", async () => {
    let reads = 0;
    let cancelled = false;
    const reader = {
      async read(): Promise<ReadableStreamReadResult<Uint8Array>> {
        reads += 1;
        if (reads === 1) {
          return { done: false, value: new Uint8Array(4 * 1024 * 1024) };
        }
        if (reads === 2) {
          return { done: false, value: new Uint8Array(3 * 1024 * 1024) };
        }
        throw new Error("The oversized request continued to be read.");
      },
      async cancel() {
        cancelled = true;
      },
    };
    const request = {
      headers: new Headers({ "content-type": "multipart/form-data; boundary=test" }),
      body: {
        getReader: () => reader,
      } as unknown as ReadableStream<Uint8Array>,
    } as Request;

    await expectValidationCode(parseProfileImageRequest(request), "REQUEST_TOO_LARGE");

    expect(cancelled).toBe(true);
    expect(reads).toBe(2);
  });

  it("rejects UID, folder, public ID, and every other client field", async () => {
    for (const field of ["uid", "folder", "public_id"]) {
      const form = new FormData();
      form.set("file", new File([ONE_PIXEL_PNG], "profile.png", { type: "image/png" }));
      form.set(field, "attacker-controlled");

      await expectValidationCode(
        parseProfileImageRequest(requestWith(form)),
        "UNEXPECTED_FIELD",
      );
    }
  });
});
