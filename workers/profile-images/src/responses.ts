const JSON_HEADERS = {
  "content-type": "application/json; charset=utf-8",
  "cache-control": "no-store",
};

export function jsonResponse(body: unknown, status = 200, headers?: HeadersInit): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...JSON_HEADERS, ...headers },
  });
}

export function errorResponse(
  status: number,
  code: string,
  message: string,
  headers?: HeadersInit,
): Response {
  return jsonResponse({ error: { code, message } }, status, headers);
}
