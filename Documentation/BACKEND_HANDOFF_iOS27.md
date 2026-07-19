# BACKEND HANDOFF — iOS 27 feature support (Session 8)

*Copy this file to the backend repo and hand it to the backend agent. It is self-contained:
it describes the current deployed contract, what the frontend is about to build, and exactly
what the backend must add/change to support it. Written 2026-07-19, during SwiftDidLoad
hackathon, judging imminent — priorities are marked accordingly.*

- Backend repo: `backend/` (FastAPI), deployed at `https://marauders-backend.azurewebsites.net`
- Frontend repo: `github.com/kartikmasiwal/Marauders`, branch `main` @ `3104366` (source of truth)
- Companion doc in frontend repo: `Documentation/iOS27_Ideation.md` (the feature plan this supports)

---

## Current deployed contract (verified live 2026-07-19 — do not break any of this)

```
GET  /health                              no auth
     -> { "ok": true, "monuments": {"taj_mahal":7,"zomato_farmhouse":3,"red_fort":1},
          "packages": [...] }             // frontend PackageCatalog reads "monuments" keys

GET  /packages/{monumentId}.zip           full package, 4 languages, music/ambient_default.mp3
GET  /packages/{monumentId}/{lang}.zip    lang ∈ en|hi|fr|es

POST /ask   header X-App-Key
     body: { monumentId, checkpointId, lang, text?, audioBase64?, skipAudio? }
     resp: { question, text, audioBase64 }   // audioBase64=="" when skipAudio:true
```

Frontend consumers today: `PackageCatalog` (/health), `PackageStore` (package zips),
`VoiceQuestionService` (/ask voice, skipAudio:false), `TajAIInsightStore` (/ask text,
skipAudio:true, checkpointId mapped from Taj chapter ids, falls back to bundled text offline).

**Context that changes your load profile:** the frontend is implementing Apple's iOS 27
Foundation Models so Q&A runs **on-device** on A17 Pro+ hardware. The engine chain becomes:
on-device model → your `/ask` → bundled fallback. Your `/ask` is no longer the primary
answer path on new iPhones — it is the **compatibility tier** for pre-A17 devices and the
**capability tier** for things the on-device model can't do. The tasks below follow from that.

---

## Task 1 — P0 · Fix the taj_mahal package data bug (ship today)

The deployed `taj_mahal.zip` contains 3 checkpoints (`cp_venue_entrance`, `cp_venue_pillar`,
`cp_venue_wall`) whose nuggets reference audio files **not present in the zip** (verified by
unzipping the live package: their nuggets have zero surviving audio). The frontend's lenient
validator silently drops them (4/7 checkpoints survive), so nothing crashes — but 3/7 of the
advertised content is dead weight in every download, and `/health` advertises `"taj_mahal": 7`.

**Do one of:** (a) add the missing audio files to the package, or (b) strip the venue
checkpoints from `taj_mahal`'s `tour.json` and update `/health` to the true count.
Either is fine; silent mismatch is not. `zomato_farmhouse` verified clean (3/3).

## Task 2 — P0 · AI grounding corpus in tour.json (enables the flagship frontend feature)

The on-device model needs rich, curated facts to answer from. Today `tour.json` has only
short display texts; the frontend's Taj "AI insight" fallback content is **hardcoded in Swift**
(`TajMapCheckpoint.chapters` — verifiedInformation, fallbackAIInformation, architecture,
historicalContext, interestingFact, visitorGuidance per chapter), which doesn't scale past
one monument.

Add to the package schema (backward-compatible — frontend decodes unknown fields as absent):

```jsonc
// per checkpoint in tour.json
"aiContext": {
  "facts": ["..."],            // 5-15 curated, verified facts, EN
  "facts_hi": ["..."], "facts_fr": ["..."], "facts_es": ["..."],   // optional translations
  "fallbackNote": { "en": "...", "hi": "...", "fr": "...", "es": "..." }  // offline insight text
}
```

Populate for all three monuments. Bump nothing: `schemaVersion` stays 1 (additive field).
This same corpus should become the grounding text your `/ask` LLM prompt uses, so on-device
and server answers agree with each other.

## Task 3 — P1 · Image input on /ask (server fallback for multimodal "What's this?")

Frontend is building camera-snapshot Q&A via the iOS 27 model's vision input. Pre-A17
devices need a server path for feature parity:

```
POST /ask   (same endpoint, additive)
     body: + imageBase64?   // JPEG, ≤1MB, camera frame
```

Rules: `imageBase64` may combine with `text`; respect `skipAudio` as today; route to a
vision-capable model with the checkpoint's `aiContext` facts in the prompt. Return the same
response shape. If the model can't identify the image, answer from checkpoint context rather
than erroring — the frontend treats any 2xx with text as success.

## Task 4 — P1 · Structured quiz endpoint (server fallback for @Generable quiz)

On-device generates the end-of-tour quiz on A17 Pro+; older devices need:

```
GET /quiz/{monumentId}?checkpoints=cp_a,cp_b&lang=en&count=5   header X-App-Key
    -> { "questions": [ { "prompt": "...", "choices": ["...","...","...","..."],
                          "answerIndex": 2, "checkpointId": "cp_a" } ] }
```

Generate strictly from `aiContext.facts` of the **listed** checkpoints (the ones the visitor
actually completed). Deterministic-ish temperature; validate `answerIndex` bounds server-side.
JSON only, no audio.

## Task 5 — P2 · /health versioning (lets the app detect package updates)

Frontend caches packages forever; when you fix Task 1 or add Task 2 fields, installed apps
never see it. Additive change:

```
GET /health -> + "packageVersions": { "taj_mahal": 3, "zomato_farmhouse": 2, "red_fort": 1 }
```

Bump a monument's integer whenever its zip content changes. Frontend will compare against the
installed version and offer re-download. (Keep the existing fields exactly as-is.)

## Task 6 — P2 · Latency telemetry header (nice-to-have)

Add `X-Answer-Source: model|cache` and timing to `/ask` responses (response header only,
body unchanged) so during judging we can quote real numbers for the skipAudio fast path
(~1-2s target) vs voice (~5-8s). No frontend dependency; purely for the demo narrative.

---

## Explicit non-tasks (don't build these)

- **No push server for Live Activities** — the frontend's Live Activities update locally
  (offline-first is the product story). Do not add APNs plumbing.
- **No TTS changes** — voice path stays as-is; on-device answers use on-device TTS.
- **No auth changes** — X-App-Key stays. But note: the frontend build machine has no
  `Secrets.xcconfig`; make sure the team knows where the current app key lives.

## Acceptance checks (run these before calling any task done)

1. `curl /health` — old fields byte-compatible; new fields present (Task 5).
2. Unzip fresh `taj_mahal.zip` — every nugget's audio files exist in the archive; checkpoint
   count matches `/health` (Task 1); every checkpoint has `aiContext.fallbackNote.en` (Task 2).
3. `POST /ask` with `skipAudio:true` + `imageBase64` of a Taj photo → 2xx, non-empty text,
   `audioBase64==""`, under ~3s (Task 3).
4. `GET /quiz/taj_mahal?checkpoints=cp_great_gate&lang=en&count=3` → valid JSON, 3 questions,
   all `answerIndex` in bounds, prompts traceable to `aiContext.facts` (Task 4).
5. Existing frontend must keep working unchanged: `POST /ask` with the *old* body shape
   (no new fields) must behave exactly as today — the shipped app on `main @ 3104366`
   depends on it mid-judging.

## Report back

When done, report per task: deployed or not, what changed in the contract (exact JSON), and
the acceptance-check outputs. Flag anything you had to change that isn't listed here —
the frontend agent will wire the client side against your report.
