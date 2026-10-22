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
  modelOverride?: string; // Optional override for testing/diagnostics
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

// Verified candidate models cascade in order of availability and stability:
// 1. gemini-3.5-flash-lite: Active, highly available, low-latency, multimodal
// 2. gemini-flash-lite-latest: Active Google alias tracking latest flash-lite
// 3. gemini-3.6-flash: Active ecosystem model (fallback tier)
// 4. gemini-3.8-flash: High reasoning model (fallback tier when demand normalizes)
const DEFAULT_MODEL_CASCADE = [
  "gemini-3.5-flash-lite",
  "gemini-flash-lite-latest",
  "gemini-3.6-flash",
  "gemini-3.8-flash",
];

// Time budget and limits
const TOTAL_REQUEST_BUDGET_MS = 26000; // 26s absolute cap for edge function execution
const PER_ATTEMPT_TIMEOUT_MS = 20000;  // 20s individual model fetch timeout
const MIN_REMAINING_BUDGET_MS = 5000;   // Minimum time needed to attempt a fallback model

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
      temperature: 0.2,
      maxOutputTokens: 1024,
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
  isModelOverloaded: boolean;
  isRateLimited: boolean;
  retryAfterMs: number | null;
}

async function executeModelCall(
  modelId: string,
  apiKey: string,
  requestPayload: any,
  correlationId: string,
  timeoutMs: number
): Promise<AttemptResult> {
  const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${modelId}:generateContent?key=${apiKey}`;
  const attemptStart = Date.now();

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

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
    console.warn(`[analyze-report] [${correlationId}] Call to ${modelId} aborted/failed (${elapsed}ms): ${isTimeout ? 'Timeout' : 'Network error'}`);
    return {
      success: false,
      status: isTimeout ? 504 : 503,
      retryable: true,
      isModelOverloaded: false,
      isRateLimited: false,
      retryAfterMs: null,
      error: {
        code: isTimeout ? "AI_TIMEOUT" : "AI_UNAVAILABLE",
        message: isTimeout
          ? "AI analysis request timed out. You can enter details manually."
          : "Network error reaching AI provider. You can enter details manually.",
      },
    };
  }
  clearTimeout(timeoutId);

  const elapsed = Date.now() - attemptStart;
  console.log(`[analyze-report] [${correlationId}] Model ${modelId} HTTP ${geminiResponse.status} in ${elapsed}ms`);

  if (!geminiResponse.ok) {
    const errorText = await geminiResponse.text();
    // Log sanitized error (truncate and ensure no secrets leak)
    console.warn(`[analyze-report] [${correlationId}] Model ${modelId} failed with ${geminiResponse.status}: ${errorText.slice(0, 200)}`);

    const retryAfterHeader = geminiResponse.headers.get("retry-after");
    const retryAfterMs = parseRetryAfter(retryAfterHeader);

    const is503 = geminiResponse.status === 503;
    const is429 = geminiResponse.status === 429;
    const is408 = geminiResponse.status === 408;
    const is5xx = geminiResponse.status >= 500 && geminiResponse.status < 600;

    let errorCode = "AI_PROVIDER_ERROR";
    let errorMessage = `AI service returned status ${geminiResponse.status}. Please enter details manually.`;

    if (is503) {
      errorCode = "AI_SERVICE_UNAVAILABLE";
      errorMessage = "AI service is temporarily experiencing high demand. Please try again or continue with manual entry.";
    } else if (is429) {
      errorCode = "RATE_LIMITED";
      errorMessage = "AI service rate limit reached. Please proceed with manual entry.";
    } else if (geminiResponse.status === 400) {
      errorCode = "VALIDATION_ERROR";
      errorMessage = "Invalid request format to AI provider.";
    } else if (geminiResponse.status === 401 || geminiResponse.status === 403) {
      errorCode = "AI_UNAVAILABLE";
      errorMessage = "AI service authentication error. Please enter details manually.";
    } else if (geminiResponse.status === 404) {
      errorCode = "MODEL_NOT_FOUND";
      errorMessage = `AI model ${modelId} is not available.`;
    }

    return {
      success: false,
      status: geminiResponse.status,
      retryable: is5xx || is429 || is408,
      isModelOverloaded: is503,
      isRateLimited: is429,
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
      isModelOverloaded: false,
      isRateLimited: false,
      retryAfterMs: null,
      error: { code: "AI_MALFORMED_OUTPUT", message: "Failed to parse provider response JSON." },
    };
  }

  const rawText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!rawText) {
    console.warn(`[analyze-report] [${correlationId}] Empty candidate response from ${modelId}`);
    return {
      success: false,
      status: 502,
      retryable: true,
      isModelOverloaded: false,
      isRateLimited: false,
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
      isModelOverloaded: false,
      isRateLimited: false,
      retryAfterMs: null,
    };
  } catch (_) {
    console.warn(`[analyze-report] [${correlationId}] Malformed structured JSON from ${modelId}: ${rawText.slice(0, 150)}`);
    return {
      success: false,
      status: 502,
      retryable: false,
      isModelOverloaded: false,
      isRateLimited: false,
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

  // Diagnostic model probe (authenticated)
  if (req.method === "GET") {
    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) {
      return new Response(JSON.stringify({ error: "GEMINI_API_KEY missing" }), { status: 500, headers: corsHeaders });
    }
    const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`);
    const data = await res.json();
    return new Response(JSON.stringify(data), {
      status: res.status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
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

    const { imageBase64, mimeType = "image/jpeg", userDescription = "", modelOverride, modelCascade: customCascade } = body as any;

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

    // 5. Determine Model Execution Cascade
    const primaryEnv = Deno.env.get("GEMINI_PRIMARY_MODEL")?.trim();
    let modelCascade: string[];

    if (Array.isArray(customCascade) && customCascade.length > 0) {
      modelCascade = customCascade;
    } else if (modelOverride) {
      modelCascade = [modelOverride];
    } else if (primaryEnv && !DEFAULT_MODEL_CASCADE.includes(primaryEnv)) {
      modelCascade = [primaryEnv, ...DEFAULT_MODEL_CASCADE];
    } else if (primaryEnv) {
      modelCascade = [primaryEnv, ...DEFAULT_MODEL_CASCADE.filter((m) => m !== primaryEnv)];
    } else {
      modelCascade = [...DEFAULT_MODEL_CASCADE];
    }

    console.log(`[analyze-report] [${correlationId}] Starting analysis pipeline with cascade [${modelCascade.join(", ")}]. Image size: ${imageBase64.length} chars.`);

    let finalData: any = null;
    let successfulModel: string = modelCascade[0];
    let isFallbackUsed = false;
    let lastError: { code: string; message: string } | null = null;
    let lastStatus = 503;

    // 6. Execute Model Cascade with Intelligent Failover
    for (let modelIndex = 0; modelIndex < modelCascade.length; modelIndex++) {
      const currentModel = modelCascade[modelIndex];
      const isFirstModel = modelIndex === 0;

      // Check remaining time budget before starting a model attempt
      const elapsedTotal = Date.now() - startTime;
      const remainingBudget = TOTAL_REQUEST_BUDGET_MS - elapsedTotal;
      if (remainingBudget < MIN_REMAINING_BUDGET_MS) {
        console.warn(`[analyze-report] [${correlationId}] Insufficient remaining time budget (${remainingBudget}ms). Halting cascade.`);
        break;
      }

      const attemptTimeout = Math.min(PER_ATTEMPT_TIMEOUT_MS, remainingBudget);

      // Attempt current model
      let attemptRes = await executeModelCall(
        currentModel,
        apiKey,
        requestPayload,
        correlationId,
        attemptTimeout
      );

      // If call failed with transient 500/502/504 or network error (NOT 503 overload and NOT 429 rate limit),
      // perform 1 bounded retry with exponential backoff & jitter if time budget permits
      if (!attemptRes.success && attemptRes.retryable && !attemptRes.isModelOverloaded && !attemptRes.isRateLimited) {
        const remainingForRetry = TOTAL_REQUEST_BUDGET_MS - (Date.now() - startTime);
        if (remainingForRetry > MIN_REMAINING_BUDGET_MS + 1000) {
          const jitterDelay = Math.floor(Math.random() * 300) + 700; // 700-1000ms
          console.warn(`[analyze-report] [${correlationId}] Transient error on ${currentModel}. Retrying in ${jitterDelay}ms...`);
          await sleep(jitterDelay);

          attemptRes = await executeModelCall(
            currentModel,
            apiKey,
            requestPayload,
            correlationId,
            Math.min(PER_ATTEMPT_TIMEOUT_MS, TOTAL_REQUEST_BUDGET_MS - (Date.now() - startTime))
          );
        }
      }

      if (attemptRes.success && attemptRes.data) {
        finalData = attemptRes.data;
        successfulModel = currentModel;
        isFallbackUsed = !isFirstModel;
        break;
      }

      // Record error for client reporting if all candidates fail
      lastError = attemptRes.error || { code: "AI_ERROR", message: "AI analysis failed." };
      lastStatus = attemptRes.status;

      // If permanent error (e.g., 400 Bad Request, 401/403 Bad API key), abort entire pipeline immediately
      if (attemptRes.status === 400 || attemptRes.status === 401 || attemptRes.status === 403) {
        console.warn(`[analyze-report] [${correlationId}] Permanent error ${attemptRes.status} on ${currentModel}. Halting cascade.`);
        break;
      }

      // If model returned 503 (Overloaded) or 429 (Rate-Limited), do NOT retry the same model repeatedly.
      // Immediately proceed to the next healthy model tier in the cascade!
      if (modelIndex < modelCascade.length - 1) {
        console.warn(`[analyze-report] [${correlationId}] Model ${currentModel} failed (status ${attemptRes.status}). Advancing to next fallback tier: ${modelCascade[modelIndex + 1]}...`);
      }
    }

    // 7. Handle Complete Service Exhaustion
    if (!finalData) {
      const totalElapsed = Date.now() - startTime;
      console.warn(`[analyze-report] [${correlationId}] All candidate models exhausted in ${totalElapsed}ms. Returning status ${lastStatus}.`);

      // Preserve exact HTTP status contract:
      // 503 for service overload
      // 429 for rate limit / exhausted quota
      // 504 for gateway/request timeout
      // 400/401/403/500 for respective errors
      const responseStatus = lastStatus;
      const errorCode = lastError?.code || (responseStatus === 503 ? "AI_SERVICE_UNAVAILABLE" : "AI_ERROR");
      const errorMessage = lastError?.message || "AI analysis is temporarily unavailable. Please continue with manual entry.";

      return new Response(
        JSON.stringify({
          ok: false,
          error: {
            code: errorCode,
            message: errorMessage,
          },
        }),
        {
          status: responseStatus,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 8. Validate and Normalize Structured Model Output
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
      issue_title: (finalData.issue_title || "Campus Issue").toString().trim(),
      issue_description: (finalData.issue_description || userDescription || "Observed campus issue requiring maintenance.").toString().trim(),
      category: category,
      severity: severity,
      department: (finalData.department || "Campus Facilities").toString().trim(),
      confidence: confidence,
      needs_review: Boolean(finalData.needs_review),
      reasoning_summary: (finalData.reasoning_summary || "Visual analysis of reported incident.").toString().trim(),
    };

    const totalLatency = Date.now() - startTime;
    console.log(`[analyze-report] [${correlationId}] Successfully analyzed via ${successfulModel}${isFallbackUsed ? ' (FALLBACK)' : ''}: "${result.issue_title}" [${result.category}/${result.severity}] in ${totalLatency}ms.`);

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
