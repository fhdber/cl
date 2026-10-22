import fs from "node:fs";
import path from "node:path";

// Overridable so the smoke test can point the server at a local mock.
export const API_BASE_URL = process.env.DRIBBBLE_API_BASE_URL ?? "https://api.dribbble.com/v2";

/** Token from the environment, or a DRIBBBLE_ACCESS_TOKEN line in .env next to the working directory. */
function readToken(): string | undefined {
  if (process.env.DRIBBBLE_ACCESS_TOKEN) return process.env.DRIBBBLE_ACCESS_TOKEN.trim();
  const env = path.join(process.cwd(), ".env");
  if (!fs.existsSync(env)) return undefined;
  const m = fs.readFileSync(env, "utf8").match(/^\s*DRIBBBLE_ACCESS_TOKEN\s*=\s*"?([^"\n]+)"?/m);
  return m?.[1].trim();
}

function httpErrorMessage(status: number, detail: string): string {
  switch (status) {
    case 401:
      return "Dribbble rejected the access token. Check DRIBBBLE_ACCESS_TOKEN in the server's environment.";
    case 403:
      return "Permission denied. The token needs the 'upload' scope to create, edit or delete shots, and you can only change your own shots. If the scope is set, the account may not be allowed API uploads: use the web uploader at https://dribbble.com/uploads/new.";
    case 404:
      return "Not found. A freshly uploaded shot returns 404 until Dribbble has processed it: wait a minute and retry. Otherwise check the ID with dribbble_list_shots.";
    case 422:
      return `Dribbble refused the request: ${detail}`;
    case 429:
      return "Rate limit reached (60 requests a minute, 1,440 a day). Wait a minute before the next call.";
    default:
      return `Dribbble API returned HTTP ${status}${detail ? `: ${detail}` : ""}.`;
  }
}

export class ApiError extends Error {
  constructor(readonly status: number, detail = "") {
    super(httpErrorMessage(status, detail));
  }
}

export interface ApiResult<T> {
  status: number;
  data: T;
  location: string | null;
  rateRemaining: number | null;
}

export async function apiRequest<T>(
  method: "GET" | "POST" | "PUT" | "DELETE",
  route: string,
  signal: AbortSignal,
  body?: FormData
): Promise<ApiResult<T>> {
  const token = readToken();
  if (!token) {
    throw new Error(
      "DRIBBBLE_ACCESS_TOKEN is not set. Create an app at https://dribbble.com/account/applications, generate a token with 'public upload' scope, and add it to the MCP server's env config. dribbble_check_image works without a token."
    );
  }
  let res: Response;
  try {
    res = await fetch(API_BASE_URL + route, {
      method,
      headers: { Authorization: `Bearer ${token}`, Accept: "application/json" },
      body,
      signal: AbortSignal.any([signal, AbortSignal.timeout(60_000)])
    });
  } catch (error) {
    if (error instanceof DOMException && error.name === "TimeoutError") {
      throw new Error("Dribbble did not respond within 60 seconds. Try again.");
    }
    throw error;
  }
  const text = await res.text();
  let data: unknown = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = text;
  }
  if (!res.ok) {
    const detail = typeof data === "object" && data && "message" in data ? String((data as { message: unknown }).message)
      : typeof data === "string" ? data.slice(0, 300) : JSON.stringify(data)?.slice(0, 300) ?? "";
    throw new ApiError(res.status, detail);
  }
  const left = res.headers.get("x-ratelimit-remaining");
  return { status: res.status, data: data as T, location: res.headers.get("location"), rateRemaining: left === null ? null : Number(left) };
}
