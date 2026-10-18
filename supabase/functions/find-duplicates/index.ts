import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface FindDuplicatesRequest {
  buildingId: string;
  category: string;
  title: string;
  description: string;
  floorId?: string;
  floorText?: string;
  locationDetails?: string;
}

interface RedactedCandidate {
  report_id: string;
  title: string;
  category: string;
  severity: string;
  building_name: string;
  floor_name: string | null;
  area_name: string | null;
  status: string;
  reported_at: string;
  similarity_score?: number;
}

// Tokenize text for semantic word overlap (removing common stopwords)
function tokenize(text: string): Set<string> {
  const stopwords = new Set([
    "a", "an", "the", "in", "on", "at", "by", "for", "with", "about",
    "against", "between", "into", "through", "during", "before", "after",
    "above", "below", "to", "from", "up", "down", "is", "are", "was", "were",
    "and", "or", "not", "this", "that", "these", "those", "near", "near by",
    "of", "it", "its", "there", "has", "have", "had", "be", "been",
  ]);

  const words = text
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, " ")
    .split(/\s+/)
    .filter((w) => w.length > 2 && !stopwords.has(w));

  return new Set(words);
}

// Jaccard similarity between two token sets
function tokenSimilarity(setA: Set<string>, setB: Set<string>): number {
  if (setA.size === 0 || setB.size === 0) return 0;
  let intersectionCount = 0;
  for (const token of setA) {
    if (setB.has(token)) intersectionCount++;
  }
  const unionCount = setA.size + setB.size - intersectionCount;
  return unionCount > 0 ? intersectionCount / unionCount : 0;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

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

    // 2. Parse Request Payload
    let body: FindDuplicatesRequest;
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

    const {
      buildingId,
      category = "other",
      title = "",
      description = "",
      floorId,
      floorText = "",
      locationDetails = "",
    } = body;

    if (!buildingId || buildingId.trim().length === 0) {
      return new Response(
        JSON.stringify({
          ok: false,
          error: {
            code: "VALIDATION_ERROR",
            message: "buildingId is required for candidate shortlisting.",
          },
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 3. Connect to Supabase
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseKey, {
      global: { headers: { Authorization: authHeader } },
    });

    // 4. Query short-listed candidates via bounded RPC or direct table query
    const { data: rawCandidates, error: queryError } = await supabase.rpc(
      "find_duplicate_candidates",
      {
        p_building_id: buildingId,
        p_category: category,
        p_floor_id: floorId || null,
        p_limit: 10,
      }
    );

    if (queryError) {
      console.error("find_duplicate_candidates RPC error:", queryError);
      return new Response(
        JSON.stringify({
          ok: true,
          data: {
            outcome: "check_unavailable",
            explanation: "Candidate lookup query failed temporarily.",
            candidates: [],
          },
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const candidatesList = (rawCandidates || []) as any[];

    if (candidatesList.length === 0) {
      return new Response(
        JSON.stringify({
          ok: true,
          data: {
            outcome: "no_match",
            explanation: "No active unresolved reports found in this building.",
            candidates: [],
          },
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // 5. Multi-Signal Scoring Engine
    const proposedTitleTokens = tokenize(title);
    const proposedDescTokens = tokenize(description);
    const proposedCombinedTokens = tokenize(`${title} ${description}`);
    const proposedLocTokens = tokenize(`${floorText} ${locationDetails}`);

    const scoredCandidates: Array<{ candidate: RedactedCandidate; score: number }> = [];

    for (const c of candidatesList) {
      let score = 0.0;

      // A. Location Signals (Up to 0.40)
      // Same building is guaranteed by the query: +0.20
      score += 0.20;

      const candFloorId = c.floor_id;
      const candFloorLabel = (c.floor_label || "").toLowerCase();
      const candLocDetails = (c.location_details || "").toLowerCase();

      // Floor comparison
      let floorMismatch = false;
      if (floorId && candFloorId) {
        if (floorId === candFloorId) {
          score += 0.15; // Exact floor ID match
        } else {
          // Different floors: significant penalty as they are separate physical locations
          score -= 0.35;
          floorMismatch = true;
        }
      } else if (floorText.trim().length > 0 && candFloorLabel.length > 0) {
        const candFloorTokens = tokenize(candFloorLabel);
        const floorSim = tokenSimilarity(tokenize(floorText), candFloorTokens);
        if (floorSim > 0.5) {
          score += 0.12;
        } else if (floorSim === 0) {
          score -= 0.25;
          floorMismatch = true;
        }
      } else {
        // Floor unspecified on either side
        score += 0.05;
      }

      // Hard score cap if floors explicitly mismatch: separate physical locations must not match
      if (floorMismatch && score > 0.30) {
        score = 0.30;
      }

      // Exact room / location details string similarity
      if (locationDetails.trim().length > 0 && candLocDetails.length > 0) {
        const candLocTokens = tokenize(candLocDetails);
        const locSim = tokenSimilarity(proposedLocTokens, candLocTokens);
        score += 0.10 * locSim;
      }

      // B. Category Compatibility (Up to 0.15)
      const candCat = (c.category || "").toLowerCase();
      if (candCat === category.toLowerCase()) {
        score += 0.15;
      } else if (candCat === "other" || category.toLowerCase() === "other") {
        score += 0.05;
      }

      // C. Description & Title Similarity (Up to 0.35)
      const candCombinedText = `${c.issue_label || ""} ${c.description || ""}`;
      const candTokens = tokenize(candCombinedText);
      const textSim = tokenSimilarity(proposedCombinedTokens, candTokens);
      score += 0.35 * textSim;

      // D. Time Proximity (Up to 0.10)
      const reportedDate = new Date(c.created_at);
      const hoursAgo = (Date.now() - reportedDate.getTime()) / (1000 * 60 * 60);
      if (hoursAgo <= 24) {
        score += 0.10; // Very recent unresolved report
      } else if (hoursAgo <= 72) {
        score += 0.05;
      } else {
        score += 0.02; // Still unresolved older report
      }

      const finalScore = Math.max(0.0, Math.min(1.0, score));

      scoredCandidates.push({
        candidate: {
          report_id: c.id,
          title: c.issue_label || "Campus Issue",
          category: c.category || "other",
          severity: c.severity || "medium",
          building_name: c.building_name || "Campus Building",
          floor_name: c.floor_label || null,
          area_name: c.location_details || null,
          status: c.status || "REPORTED",
          reported_at: c.created_at,
          similarity_score: Math.round(finalScore * 100) / 100,
        },
        score: finalScore,
      });
    }

    // Sort by descending score
    scoredCandidates.sort((a, b) => b.score - a.score);

    const topCandidate = scoredCandidates[0];
    const topScore = topCandidate ? topCandidate.score : 0;

    let outcome: "likely_duplicate" | "possible_match" | "no_match" = "no_match";
    let explanation = "No matching active issues detected.";

    if (topCandidate) {
      const topCandRow = candidatesList.find((c) => c.id === topCandidate.candidate.report_id);
      const topCandText = `${topCandRow?.issue_label || topCandidate.candidate.title} ${topCandRow?.description || ""}`;
      const topTextSim = tokenSimilarity(proposedCombinedTokens, tokenize(topCandText));

      // Category and building alone are NEVER sufficient without text/incident correlation
      if (topTextSim >= 0.15) {
        if (topScore >= 0.65 && topTextSim >= 0.25) {
          outcome = "likely_duplicate";
          explanation = `High similarity to an active report in ${topCandidate.candidate.building_name}${
            topCandidate.candidate.floor_name ? ` (${topCandidate.candidate.floor_name})` : ""
          }. Both reports appear to describe the same incident.`;
        } else if (topScore >= 0.45) {
          outcome = "possible_match";
          explanation = `Potential match found in ${topCandidate.candidate.building_name}${
            topCandidate.candidate.floor_name ? ` (${topCandidate.candidate.floor_name})` : ""
          }. Review before submitting a new report.`;
        }
      }
    }

    const filteredCandidates = scoredCandidates
      .filter((s) => s.score >= 0.35)
      .slice(0, 3)
      .map((s) => s.candidate);

    return new Response(
      JSON.stringify({
        ok: true,
        data: {
          outcome: outcome,
          explanation: explanation,
          candidates: outcome === "no_match" ? [] : filteredCandidates,
        },
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error: any) {
    console.error("Unhandled error in find-duplicates Edge Function:", error);
    return new Response(
      JSON.stringify({
        ok: true,
        data: {
          outcome: "check_unavailable",
          explanation: "Duplicate checking service encountered an unexpected error.",
          candidates: [],
        },
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
