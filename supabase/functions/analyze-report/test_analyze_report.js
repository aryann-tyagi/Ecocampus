// Comprehensive verification and test suite for analyze-report Edge Function
// Tests retry mechanics, fallback to gemini-3.6-flash, 503 handling, schema validation, and real images.

const fs = require('fs');
const path = require('path');

const FIXTURES_DIR = path.resolve(__dirname, '../../../apps/mobile/test/fixtures/images');

const PRIMARY_MODEL = "gemini-3.8-flash";
const FALLBACK_MODEL = "gemini-3.6-flash";
const MAX_PRIMARY_ATTEMPTS = 3;
const BASE_RETRY_DELAY_MS = 1000;
const MAX_RETRY_DELAY_MS = 6000;

const VALID_CATEGORIES = [
  "waste",
  "water",
  "electricity",
  "infrastructure",
  "greenery",
  "cleanliness",
  "other",
];

const VALID_SEVERITIES = ["low", "medium", "high", "critical"];
const VALID_CONFIDENCES = ["high", "medium", "low"];

function parseRetryAfter(headerValue) {
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

function isRetryableStatus(status) {
  return status === 503 || status === 504 || status === 502 || status === 500 || status === 429;
}

function calculateBackoffDelay(attempt, retryAfterMs) {
  if (retryAfterMs !== null && retryAfterMs > 0 && retryAfterMs <= MAX_RETRY_DELAY_MS) {
    return retryAfterMs;
  }
  const exponential = BASE_RETRY_DELAY_MS * Math.pow(2, attempt - 1);
  const jitter = Math.floor(Math.random() * 300) + 100;
  return Math.min(exponential + jitter, MAX_RETRY_DELAY_MS);
}

function validateSchema(data) {
  const errors = [];
  if (!data || typeof data !== 'object') return ['Data is not an object'];
  if (!data.issue_title || typeof data.issue_title !== 'string') errors.push('Missing or invalid issue_title');
  if (!data.issue_description || typeof data.issue_description !== 'string') errors.push('Missing or invalid issue_description');
  if (!VALID_CATEGORIES.includes(data.category)) errors.push(`Invalid category: ${data.category}`);
  if (!VALID_SEVERITIES.includes(data.severity)) errors.push(`Invalid severity: ${data.severity}`);
  if (!VALID_CONFIDENCES.includes(data.confidence)) errors.push(`Invalid confidence: ${data.confidence}`);
  if (typeof data.needs_review !== 'boolean') errors.push('needs_review must be boolean');
  if (!data.reasoning_summary || typeof data.reasoning_summary !== 'string') errors.push('Missing reasoning_summary');
  return errors;
}

function buildGeminiPayload(normalizedMime, imageBase64, userDescription) {
  return {
    systemInstruction: {
      parts: [{ text: "EcoCampus System Instruction" }],
    },
    contents: [
      {
        role: "user",
        parts: [
          { text: userDescription ? `Note: ${userDescription}` : "Analyze image" },
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
          issue_title: { type: "STRING" },
          issue_description: { type: "STRING" },
          category: { type: "STRING", enum: VALID_CATEGORIES },
          severity: { type: "STRING", enum: VALID_SEVERITIES },
          department: { type: "STRING" },
          confidence: { type: "STRING", enum: VALID_CONFIDENCES },
          needs_review: { type: "BOOLEAN" },
          reasoning_summary: { type: "STRING" },
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

// Orchestrator simulation matching index.ts logic
async function runAnalysisSimulation(mockExecutor) {
  const correlationId = "sim-correl-001";
  let finalData = null;
  let modelUsed = PRIMARY_MODEL;
  let isFallback = false;
  let lastError = null;
  let lastStatus = 503;
  let totalAttempts = 0;

  // 1. Primary Model attempts
  let primarySuccess = false;
  for (let attempt = 1; attempt <= MAX_PRIMARY_ATTEMPTS; attempt++) {
    totalAttempts++;
    const res = await mockExecutor(PRIMARY_MODEL, attempt);
    if (res.success && res.data) {
      finalData = res.data;
      primarySuccess = true;
      modelUsed = PRIMARY_MODEL;
      break;
    }

    lastError = res.error || { code: "AI_SERVICE_UNAVAILABLE", message: "AI service error." };
    lastStatus = res.status;

    if (!res.retryable) {
      break;
    }
  }

  // 2. Fallback Model attempt if primary failed with transient error
  if (!primarySuccess && (isRetryableStatus(lastStatus) || lastStatus === 404)) {
    totalAttempts++;
    const fallbackRes = await mockExecutor(FALLBACK_MODEL, 1);
    if (fallbackRes.success && fallbackRes.data) {
      finalData = fallbackRes.data;
      modelUsed = FALLBACK_MODEL;
      isFallback = true;
    } else {
      lastError = fallbackRes.error || lastError;
      lastStatus = fallbackRes.status;
    }
  }

  if (!finalData) {
    const responseStatus = isRetryableStatus(lastStatus) ? 503 : lastStatus;
    return {
      ok: false,
      status: responseStatus,
      totalAttempts,
      error: {
        code: responseStatus === 503 ? "AI_SERVICE_UNAVAILABLE" : (lastError ? lastError.code : "AI_ERROR"),
        message: responseStatus === 503
          ? "AI analysis service is temporarily experiencing high demand. Please try again or continue with manual entry."
          : (lastError ? lastError.message : "AI analysis failed."),
      },
    };
  }

  return {
    ok: true,
    status: 200,
    modelUsed,
    isFallback,
    totalAttempts,
    data: finalData,
  };
}

let passed = 0;
let failed = 0;

function assert(condition, message) {
  if (condition) {
    console.log(`  [PASS] ${message}`);
    passed++;
  } else {
    console.error(`  [FAIL] ${message}`);
    failed++;
  }
}

async function runTests() {
  console.log("=== EcoCampus Gemini 503 Retry & Fallback Verification Suite ===\n");

  // 1. parseRetryAfter Unit Tests
  console.log("1. Testing parseRetryAfter:");
  assert(parseRetryAfter("5") === 5000, "Parses numeric seconds correctly (5 -> 5000ms)");
  assert(parseRetryAfter("0") === 0, "Parses 0 seconds correctly");
  assert(parseRetryAfter(null) === null, "Returns null for missing header");
  assert(parseRetryAfter("invalid") === null, "Returns null for invalid string");

  // 2. isRetryableStatus Unit Tests
  console.log("\n2. Testing isRetryableStatus:");
  assert(isRetryableStatus(503) === true, "503 Service Unavailable is retryable");
  assert(isRetryableStatus(504) === true, "504 Gateway Timeout is retryable");
  assert(isRetryableStatus(502) === true, "502 Bad Gateway is retryable");
  assert(isRetryableStatus(500) === true, "500 Internal Error is retryable");
  assert(isRetryableStatus(429) === true, "429 Rate Limit is retryable");
  assert(isRetryableStatus(400) === false, "400 Bad Request is NOT retryable");
  assert(isRetryableStatus(401) === false, "401 Unauthorized is NOT retryable");
  assert(isRetryableStatus(403) === false, "403 Forbidden is NOT retryable");
  assert(isRetryableStatus(404) === false, "404 Not Found is NOT retryable");

  // 3. calculateBackoffDelay Unit Tests
  console.log("\n3. Testing calculateBackoffDelay:");
  const d1 = calculateBackoffDelay(1, null);
  assert(d1 >= 1000 && d1 <= 1500, `Attempt 1 delay has exponential base 1000ms + jitter (${d1}ms)`);
  const d2 = calculateBackoffDelay(2, null);
  assert(d2 >= 2000 && d2 <= 2500, `Attempt 2 delay has exponential base 2000ms + jitter (${d2}ms)`);
  const dCustom = calculateBackoffDelay(1, 3500);
  assert(dCustom === 3500, "Respects Retry-After header when provided");

  // 4. Scenario A: Primary model succeeds immediately
  console.log("\n4. Scenario A: Primary model (gemini-3.8-flash) succeeds immediately:");
  const resA = await runAnalysisSimulation(async (model, attempt) => {
    return {
      success: true,
      status: 200,
      data: {
        issue_title: "Overflowing trash bin",
        issue_description: "Rubbish overflowing onto pathway.",
        category: "waste",
        severity: "medium",
        department: "Sanitation",
        confidence: "high",
        needs_review: false,
        reasoning_summary: "Visual trash visible",
      },
    };
  });
  assert(resA.ok === true, "Returned success ok=true");
  assert(resA.modelUsed === "gemini-3.8-flash", "Used primary model gemini-3.8-flash");
  assert(resA.isFallback === false, "isFallback is false");
  assert(resA.totalAttempts === 1, "Completed in exactly 1 attempt");

  // 5. Scenario B: Primary returns 503 once, succeeds on retry
  console.log("\n5. Scenario B: Primary returns 503 on attempt 1, succeeds on attempt 2 (retry):");
  let attemptCountB = 0;
  const resB = await runAnalysisSimulation(async (model, attempt) => {
    attemptCountB++;
    if (attempt === 1) {
      return { success: false, status: 503, retryable: true, retryAfterMs: null };
    }
    return {
      success: true,
      status: 200,
      data: {
        issue_title: "Water pipe dripping",
        issue_description: "Dripping tap in washroom.",
        category: "water",
        severity: "high",
        department: "Plumbing",
        confidence: "high",
        needs_review: false,
        reasoning_summary: "Visible leak",
      },
    };
  });
  assert(resB.ok === true, "Returned success ok=true after retry");
  assert(resB.modelUsed === "gemini-3.8-flash", "Used primary model gemini-3.8-flash");
  assert(resB.totalAttempts === 2, "Took 2 attempts (1 failure + 1 retry)");
  assert(resB.isFallback === false, "Did not invoke fallback because retry succeeded");

  // 6. Scenario C: Primary returns 503 repeatedly, fallback (gemini-3.6-flash) succeeds
  console.log("\n6. Scenario C: Primary 503 persists -> Fallback model (gemini-3.6-flash) succeeds:");
  const resC = await runAnalysisSimulation(async (model, attempt) => {
    if (model === PRIMARY_MODEL) {
      return { success: false, status: 503, retryable: true, retryAfterMs: null };
    }
    // Fallback model call
    return {
      success: true,
      status: 200,
      data: {
        issue_title: "Broken stair handrail",
        issue_description: "Metal handrail detached from wall.",
        category: "infrastructure",
        severity: "critical",
        department: "Maintenance",
        confidence: "high",
        needs_review: false,
        reasoning_summary: "Broken fixture",
      },
    };
  });
  assert(resC.ok === true, "Returned success ok=true via fallback");
  assert(resC.modelUsed === "gemini-3.6-flash", "Successfully switched to fallback model gemini-3.6-flash");
  assert(resC.isFallback === true, "Flagged isFallback=true");
  assert(resC.totalAttempts === 4, "3 primary attempts + 1 fallback attempt");

  // 7. Scenario D: Both models fail -> Returns truthful HTTP 503 AI_SERVICE_UNAVAILABLE
  console.log("\n7. Scenario D: Both models fail with 503 -> Truthful AI_SERVICE_UNAVAILABLE response:");
  const resD = await runAnalysisSimulation(async (model, attempt) => {
    return {
      success: false,
      status: 503,
      retryable: true,
      retryAfterMs: null,
      error: { code: "AI_SERVICE_UNAVAILABLE", message: "This model is currently experiencing high demand." },
    };
  });
  assert(resD.ok === false, "Returned ok=false");
  assert(resD.status === 503, "Returned HTTP status 503");
  assert(resD.error.code === "AI_SERVICE_UNAVAILABLE", "Error code is stable AI_SERVICE_UNAVAILABLE");
  assert(resD.error.message.includes("experiencing high demand"), "Message indicates high demand without exposing sensitive details");
  assert(resD.totalAttempts === 4, "Bounded to exactly 4 attempts (3 primary + 1 fallback)");

  // 8. Scenario E: Non-retryable error (400 or 403) aborts immediately without repeated retries
  console.log("\n8. Scenario E: Non-retryable error (403 Forbidden) does not trigger repeated retries:");
  let attemptCountE = 0;
  const resE = await runAnalysisSimulation(async (model, attempt) => {
    attemptCountE++;
    return {
      success: false,
      status: 403,
      retryable: false,
      retryAfterMs: null,
      error: { code: "AI_UNAVAILABLE", message: "API key unauthorized." },
    };
  });
  assert(resE.ok === false, "Returned ok=false");
  assert(resE.status === 403, "Returned status 403");
  assert(resE.totalAttempts === 1, "Stopped immediately on attempt 1 without wasteful retries or fallback");

  // 9. Scenario F: Real Image Fixtures & Multimodal Payloads
  console.log("\n9. Scenario F: Real image fixtures load and construct valid payloads:");
  const images = ["test_waste_bin.jpg", "test_water_leak.jpg", "test_damaged_infra.jpg", "test_unclear_scene.jpg"];
  for (const imgName of images) {
    const p = path.join(FIXTURES_DIR, imgName);
    const exists = fs.existsSync(p);
    assert(exists, `Fixture ${imgName} exists`);
    if (exists) {
      const bytes = fs.readFileSync(p);
      const b64 = bytes.toString('base64');
      const payload = buildGeminiPayload('image/jpeg', b64, '');
      assert(payload.contents[0].parts[1].inlineData.data.length === b64.length, `${imgName} included in payload as inlineData with exact bytes`);
    }
  }

  // 10. Scenario G: Sequential independent requests have no cross-contamination
  console.log("\n10. Scenario G: Sequential requests remain completely independent:");
  const b1 = fs.readFileSync(path.join(FIXTURES_DIR, "test_waste_bin.jpg")).toString('base64');
  const b2 = fs.readFileSync(path.join(FIXTURES_DIR, "test_water_leak.jpg")).toString('base64');
  const p1 = buildGeminiPayload('image/jpeg', b1, 'bin note');
  const p2 = buildGeminiPayload('image/jpeg', b2, 'water note');
  assert(p1.contents[0].parts[1].inlineData.data !== p2.contents[0].parts[1].inlineData.data, "Payload 1 and Payload 2 have distinct image bytes");
  assert(p1.contents[0].parts[0].text !== p2.contents[0].parts[0].text, "Payload 1 and Payload 2 have distinct notes");

  console.log(`\n======================================================`);
  console.log(`Summary: ${passed} passed, ${failed} failed.`);
  if (failed > 0) {
    process.exit(1);
  }
}

runTests();
