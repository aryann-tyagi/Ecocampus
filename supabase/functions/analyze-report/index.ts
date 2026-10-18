import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface AnalyzeReportRequest {
  imageBase64?: string;
  storagePath?: string;
  mimeType?: string;
  userDescription?: string;
  requestId?: string;
}

const VALID_CATEGORIES = [
  "waste",
  "water",
  "electricity",
  "infrastructure",
  "greenery",
  "cleanliness",
  "other",
] as const;

const VALID_SEVERITIES = ["low", "medium", "high", "critical"] as const;
const VALID_CONFIDENCES = ["high", "medium", "low"] as const;

// Primary: Modern high-performance workhorse model with enhanced vision & deep reasoning
const PRIMARY_MODEL = "gemini-3.8-flash";
// Secondary Fallback: Verified stable multimodal model with structured JSON support
const SECONDARY_FALLBACK_MODEL = "gemini-3.6-flash";
// Tertiary Fallback: High-throughput, cost-effective multimodal model
const TERTIARY_FALLBACK_MODEL = "gemini-3.5-flash-lite";

const MAX_PRIMARY_ATTEMPTS = 2; // 1 initial + up to 1 retry
const BASE_RETRY_DELAY_MS = 1000;
const MAX_RETRY_DELAY_MS = 4000;
const REQUEST_TIMEOUT_MS = 20000; // 20s per individual attempt for vision models

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function parseRetryAfter(headerValue: string | null): number | null {
  if (!headerValue) return null;
  const trimmed = headerValue.trim();
  const seconds = Number(trimmed);
  if (!isNaN(seconds) && seconds >= 0) {
    return Math.round(seconds * 1000);
  }
  const dateMs = Date.parse(trimmed);
  if (!isNaN(dateMs)) {
    const diff = dateMs - Date.now();
    return diff > 0 ? diff : 0;
  }
  return null;
}

function isRetryableStatus(status: number): boolean {
  // Transient server errors & temporary overload
  return status === 503 || status === 504 || status === 502 || status === 500 || status === 429;
}

function calculateBackoffDelay(attempt: number, retryAfterMs: number | null): number {
  if (retryAfterMs !== null && retryAfterMs > 0 && retryAfterMs <= MAX_RETRY_DELAY_MS) {
    return retryAfterMs;
  }
  const exponential = BASE_RETRY_DELAY_MS * Math.pow(2, attempt - 1);
  const jitter = Math.floor(Math.random() * 300) + 100;
  return Math.min(exponential + jitter, MAX_RETRY_DELAY_MS);
}

function buildGeminiPayload(
  normalizedMime: string,
  imageBase64: string,
  userDescription: string
) {
  const systemInstruction = `You are the EcoCampus Environmental & Infrastructure Intelligence Analyzer.
Your task is to analyze the provided photograph of an actual university campus incident.

Core Evidence-Based Rules:
1. Examine the visual evidence in the photograph first and foremost. Base your findings ONLY on what is visually verifiable in the image.
2. If the user provided notes, treat them as secondary context, NOT verified truth. Never prioritize user claims over clear visual evidence.
3. Category MUST be strictly one of:
   - "waste": Solid waste accumulation, litter, overflowing trash/recycling bins, illegal dumping.
   - "water": Leaking taps, burst/dripping pipes, ponding water, flooded corridors, fixture leak.
   - "electricity": Flickering lights, exposed wiring, dead solar panels, broken outlets, tripped circuits.
   - "infrastructure": Broken benches, cracked tiles/walls, damaged doors/windows, broken handrails, structural defects.
   - "greenery": Fallen branches, overgrown turf/brush, damaged trees or landscaping on campus grounds.
   - "cleanliness": Unhygienic surfaces, floor spills, bathroom grime, stains requiring housekeeping.
   - "other": Campus incidents that do not fit the above categories.
4. Severity MUST be one of:
   - "low": Minor cosmetic or small localized defect.
   - "medium": Moderate disruption affecting a room, path, or small group.
   - "high": Substantial damage or spreading disruption (e.g. pipe dripping heavily onto electrical equipment).
   - "critical": Immediate life-safety or structural hazard (e.g. exposed live wire in wet area, structural collapse risk).
5. Confidence MUST be one of: "high", "medium", "low".
6. Ambiguity Handling: If the photograph is blurry, dark, unrelated, or shows no clear campus problem, you MUST set "needs_review": true, "confidence": "low", and clearly describe the visual ambiguity in "reasoning_summary".
7. Never invent measurements, specific room numbers, or unobserved causes.
8. Output MUST strictly conform to the provided JSON schema.`;

  const userPrompt = userDescription.trim().length > 0
    ? `Optional student note: "${userDescription.trim()}". Analyze the visual evidence in the image to identify the actual campus issue.`
    : `Analyze the visual evidence in the image to identify the actual campus issue.`;

  return {
    systemInstruction: {
      parts: [{ text: systemInstruction }],
    },
    contents: [
      {
        role: "user",
        parts: [
          { text: userPrompt },
          {
            inlineData: {
              mimeType: normalizedMime,
              data: imageBase64,
            },
          },
        ],
      },
    ],
    generationConfig: {
      responseMimeType: "application/json",
      responseSchema: {
        type: "OBJECT",
        properties: {
          issue_title: {
            type: "STRING",
            description: "Specific, concise 3-7 word title reflecting visible defect in the photo",
          },
          issue_description: {
            type: "STRING",
            description: "Factual, evidence-based description of what is physically visible",
          },
          category: {
            type: "STRING",
            enum: VALID_CATEGORIES,
          },
          severity: {
            type: "STRING",
            enum: VALID_SEVERITIES,
          },
          department: {
            type: "STRING",
            description: "Responsible university facility or maintenance team",
          },
          confidence: {
            type: "STRING",
            enum: VALID_CONFIDENCES,
          },
          needs_review: {
            type: "BOOLEAN",
            description: "True if image is blurry, ambiguous, or no clear issue is observable",
          },
          reasoning_summary: {
            type: "STRING",
            description: "Concrete visual justification detailing observable evidence in the photograph",
          },
        },
        required: [
          "issue_title",
          "issue_description",
          "category",
          "severity",
          "department",
          "confidence",
          "needs_review",
          "reasoning_summary",
        ],
      },
    },
  };
}

interface AttemptResult {
  success: boolean;
  status: number;
  data?: any;
  error?: {
    code: string;
    message: string;
  };
  retryable: boolean;
  retryAfterMs: number | null;
}

async function executeModelCall(
  modelId: string,
  apiKey: string,
  requestPayload: any,
  correlationId: string,
  attemptNumber: number
): Promise<AttemptResult> {
  const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${modelId}:generateContent?key=${apiKey}`;
  const attemptStart = Date.now();

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  let geminiResponse: Response;
  try {
    geminiResponse = await fetch(geminiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(requestPayload),
      signal: controller.signal,
    });
  } catch (err: unknown) {
    clearTimeout(timeoutId);
    const isTimeout = err instanceof Error && err.name === "AbortError";
    const elapsed = Date.now() - attemptStart;
    console.error(`[analyze-report] [${correlationId}] Attempt ${attemptNumber} on ${modelId} failed (${elapsed}ms): ${isTimeout ? 'Timeout' : 'Network error'}`);
    return {
      success: false,
      status: isTimeout ? 504 : 503,
      retryable: true,
      retryAfterMs: null,
      error: {
        code: isTimeout ? "AI_TIMEOUT" : "AI_UNAVAILABLE",
        message: isTimeout ? "Gemini request timed out." : "Network error reaching AI provider.",
      },
    };
  }
  clearTimeout(timeoutId);

  const elapsed = Date.now() - attemptStart;
  console.log(`[analyze-report] [${correlationId}] Attempt ${attemptNumber} on ${modelId} status: ${geminiResponse.status} (${elapsed}ms)`);

  if (!geminiResponse.ok) {
    const errorText = await geminiResponse.text();
    console.error(`[analyze-report] [${correlationId}] Model ${modelId} error (${geminiResponse.status}): ${errorText.slice(0, 300)}`);

    const retryAfterHeader = geminiResponse.headers.get("retry-after");
    const retryAfterMs = parseRetryAfter(retryAfterHeader);
    const retryable = isRetryableStatus(geminiResponse.status);

    let errorCode = "AI_PROVIDER_ERROR";
    let errorMessage = `AI service returned status ${geminiResponse.status}.`;
    if (geminiResponse.status === 503) {
      errorCode = "AI_SERVICE_UNAVAILABLE";
      errorMessage = "AI service is temporarily experiencing high demand. Please try again or continue with manual entry.";
    } else if (geminiResponse.status === 429) {
      errorCode = "RATE_LIMITED";
      errorMessage = "AI service is currently rate-limited. Please proceed with manual entry.";
    } else if (geminiResponse.status === 400) {
      errorCode = "VALIDATION_ERROR";
      errorMessage = "Invalid request format to AI provider.";
    } else if (geminiResponse.status === 401 || geminiResponse.status === 403) {
      errorCode = "AI_UNAVAILABLE";
      errorMessage = "AI service authentication error.";
    }

    return {
      success: false,
      status: geminiResponse.status,
      retryable,
      retryAfterMs,
      error: { code: errorCode, message: errorMessage },
    };
  }

  // Parse successful response
  let geminiData: any;
  try {
    geminiData = await geminiResponse.json();
  } catch (_) {
    return {
      success: false,
      status: 502,
      retryable: true,
      retryAfterMs: null,
      error: { code: "AI_MALFORMED_OUTPUT", message: "Failed to parse provider response JSON." },
    };
  }

  const rawText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!rawText) {
    console.error(`[analyze-report] [${correlationId}] Empty candidate response from ${modelId}`);
    return {
      success: false,
      status: 502,
      retryable: true,
      retryAfterMs: null,
      error: { code: "AI_EMPTY_RESPONSE", message: "AI provider returned empty response." },
    };
  }

  try {
    const parsed = JSON.parse(rawText);
    return {
      success: true,
      status: 200,
      data: parsed,
      retryable: false,
      retryAfterMs: null,
    };
  } catch (_) {
    console.error(`[analyze-report] [${correlationId}] Malformed structured JSON from ${modelId}: ${rawText.slice(0, 200)}`);
    return {
      success: false,
      status: 502,
      retryable: false,
      retryAfterMs: null,
      error: { code: "AI_MALFORMED_OUTPUT", message: "AI output could not be parsed as structured JSON." },
    };
  }
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const correlationId = crypto.randomUUID();
  const startTime = Date.now();

  try {
    // 1. Authenticate Request
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({
          ok: false,
          error: {
            code: "UNAUTHENTICATED",
            message: "Missing Authorization header.",
          },
        }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 2. Parse and Validate Request Payload
    let body: AnalyzeReportRequest;
    try {
      body = await req.json();
    } catch (_) {
      return new Response(
        JSON.stringify({
          ok: false,
          error: {
            code: "VALIDATION_ERROR",
            message: "Invalid JSON request body.",
          },
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const { imageBase64, mimeType = "image/jpeg", userDescription = "" } = body;

    if (!imageBase64 || imageBase64.trim().length === 0) {
      return new Response(
        JSON.stringify({
          ok: false,
          error: {
            code: "VALIDATION_ERROR",
            message: "Missing image data for AI analysis.",
          },
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Validate image MIME type
    const validMimes = ["image/jpeg", "image/png", "image/webp"];
    const normalizedMime = mimeType.toLowerCase().trim();
    if (!validMimes.includes(normalizedMime)) {
      return new Response(
        JSON.stringify({
          ok: false,
          error: {
            code: "VALIDATION_ERROR",
            message: `Unsupported image MIME type: ${mimeType}. Expected image/jpeg, image/png, or image/webp.`,
          },
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 3. Check Gemini API Key from Supabase Secrets
    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) {
      console.error(`[analyze-report] [${correlationId}] GEMINI_API_KEY secret is missing.`);
      return new Response(
        JSON.stringify({
          ok: false,
          error: {
            code: "AI_UNAVAILABLE",
            message: "Gemini API key is not configured in Supabase secrets.",
          },
        }),
        {
          status: 503,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 4. Construct Multimodal Payload
    const requestPayload = buildGeminiPayload(normalizedMime, imageBase64, userDescription);
    console.log(`[analyze-report] [${correlationId}] Starting AI issue analysis with primary model ${PRIMARY_MODEL} (${normalizedMime}, ${imageBase64.length} chars).`);

    let finalData: any = null;
    let modelUsed: string = PRIMARY_MODEL;
    let isFallback = false;
    let lastError: { code: string; message: string } | null = null;
    let lastStatus = 503;

    // 5. Attempt Primary Model with Bounded Retries (Up to 3 total attempts)
    let primarySuccess = false;
    for (let attempt = 1; attempt <= MAX_PRIMARY_ATTEMPTS; attempt++) {
      const res = await executeModelCall(PRIMARY_MODEL, apiKey, requestPayload, correlationId, attempt);
      if (res.success && res.data) {
        finalData = res.data;
        primarySuccess = true;
        modelUsed = PRIMARY_MODEL;
        break;
      }

      lastError = res.error || { code: "AI_SERVICE_UNAVAILABLE", message: "AI service error." };
      lastStatus = res.status;

      // If error is NOT retryable (e.g. 400 Bad Request, 401/403 Bad Key), abort retries
      if (!res.retryable) {
        console.warn(`[analyze-report] [${correlationId}] Non-retryable status ${res.status} on primary model ${PRIMARY_MODEL}. Aborting primary attempts.`);
        break;
      }

      // If we haven't reached max attempts, backoff and retry
      if (attempt < MAX_PRIMARY_ATTEMPTS) {
        const delay = calculateBackoffDelay(attempt, res.retryAfterMs);
        console.warn(`[analyze-report] [${correlationId}] Primary model returned ${res.status}. Backing off for ${delay}ms before attempt ${attempt + 1}...`);
        await sleep(delay);
      }
    }

    // 6. Attempt Secondary Fallback Model Once if Primary Failed with Transient Error
    let secondarySuccess = false;
    if (!primarySuccess && (isRetryableStatus(lastStatus) || lastStatus === 404)) {
      console.warn(`[analyze-report] [${correlationId}] Primary model ${PRIMARY_MODEL} failed (status ${lastStatus}). Attempting secondary fallback ${SECONDARY_FALLBACK_MODEL}...`);
      const fallbackRes = await executeModelCall(SECONDARY_FALLBACK_MODEL, apiKey, requestPayload, correlationId, 1);
      if (fallbackRes.success && fallbackRes.data) {
        finalData = fallbackRes.data;
        modelUsed = SECONDARY_FALLBACK_MODEL;
        isFallback = true;
        secondarySuccess = true;
        const totalElapsed = Date.now() - startTime;
        console.log(`[analyze-report] [${correlationId}] Secondary fallback model ${SECONDARY_FALLBACK_MODEL} succeeded after primary failure. Total elapsed: ${totalElapsed}ms.`);
      } else {
        lastError = fallbackRes.error || lastError;
        lastStatus = fallbackRes.status;
        console.error(`[analyze-report] [${correlationId}] Secondary fallback model ${SECONDARY_FALLBACK_MODEL} failed with status ${fallbackRes.status}.`);
      }
    }

    // 7. Attempt Tertiary Fallback Model Once if Secondary Also Failed with Transient Error
    if (!primarySuccess && !secondarySuccess && (isRetryableStatus(lastStatus) || lastStatus === 404)) {
      console.warn(`[analyze-report] [${correlationId}] Secondary fallback model ${SECONDARY_FALLBACK_MODEL} failed (status ${lastStatus}). Attempting tertiary fallback ${TERTIARY_FALLBACK_MODEL}...`);
      const tertiaryRes = await executeModelCall(TERTIARY_FALLBACK_MODEL, apiKey, requestPayload, correlationId, 1);
      if (tertiaryRes.success && tertiaryRes.data) {
        finalData = tertiaryRes.data;
        modelUsed = TERTIARY_FALLBACK_MODEL;
        isFallback = true;
        const totalElapsed = Date.now() - startTime;
        console.log(`[analyze-report] [${correlationId}] Tertiary fallback model ${TERTIARY_FALLBACK_MODEL} succeeded. Total elapsed: ${totalElapsed}ms.`);
      } else {
        lastError = tertiaryRes.error || lastError;
        lastStatus = tertiaryRes.status;
        console.error(`[analyze-report] [${correlationId}] Tertiary fallback model ${TERTIARY_FALLBACK_MODEL} also failed with status ${tertiaryRes.status}.`);
      }
    }

    // 8. Handle Exhaustion / Service Failure
    if (!finalData) {
      const totalElapsed = Date.now() - startTime;
      console.error(`[analyze-report] [${correlationId}] All model attempts failed after ${totalElapsed}ms. Final status: ${lastStatus}.`);
      
      const responseStatus = isRetryableStatus(lastStatus) ? 503 : lastStatus;
      return new Response(
        JSON.stringify({
          ok: false,
          error: {
            code: responseStatus === 503 ? "AI_SERVICE_UNAVAILABLE" : (lastError?.code || "AI_ERROR"),
            message: responseStatus === 503
              ? "AI analysis service is temporarily experiencing high demand. Please try again or continue with manual entry."
              : (lastError?.message || "AI analysis failed. Please continue with manual entry."),
          },
        }),
        {
          status: responseStatus,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 9. Validate and Normalize Structured Model Output
    let category = (finalData.category || "other").toString().toLowerCase().trim();
    if (!VALID_CATEGORIES.includes(category as any)) {
      category = "other";
    }

    let severity = (finalData.severity || "medium").toString().toLowerCase().trim();
    if (!VALID_SEVERITIES.includes(severity as any)) {
      severity = "medium";
    }

    let confidence = (finalData.confidence || "medium").toString().toLowerCase().trim();
    if (!VALID_CONFIDENCES.includes(confidence as any)) {
      confidence = "medium";
    }

    const result = {
      issue_title: finalData.issue_title || "Campus Issue",
      issue_description: finalData.issue_description || userDescription || "Observed campus issue requiring maintenance.",
      category: category,
      severity: severity,
      department: finalData.department || "Campus Facilities",
      confidence: confidence,
      needs_review: Boolean(finalData.needs_review),
      reasoning_summary: finalData.reasoning_summary || "Visual analysis of reported incident.",
    };

    const totalLatency = Date.now() - startTime;
    console.log(`[analyze-report] [${correlationId}] Successfully classified via ${modelUsed}${isFallback ? ' (FALLBACK)' : ''}: "${result.issue_title}" [${result.category}/${result.severity}] in ${totalLatency}ms.`);

    return new Response(
      JSON.stringify({
        ok: true,
        data: result,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error: any) {
    console.error(`[analyze-report] [${correlationId}] Unhandled server exception:`, error);
    return new Response(
      JSON.stringify({
        ok: false,
        error: {
          code: "INTERNAL_ERROR",
          message: error?.message || "Internal server error occurred.",
        },
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
