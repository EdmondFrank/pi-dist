# Glossary

Terms from *Jev Engineering for Coding Agents* (2026 working note), with section references. Alphabetical.

- **AGENTS.md** — instructions file, loaded in full today; notes propose condition-conditional loading of its sections (§VIII).
- **ast-grep** — candidate built-in: structural search; native angle is "load manual once, generate N queries, filter by relevance" (§XI).
- **ast-outline** — candidate built-in: structural outline; hierarchical calling — pick the sub-tree to inspect (§XI).
- **Batteries debate** — whether agents ship built-in capabilities; exists only because every built-in costs context permanently (§II.F, §VII).
- **Chunk** — an addressable, typed unit of explicit state that can be scored and shown/hidden per query (Fig. 1, §V).
- **Compaction** — generic compression of one shared state, applied before the next question is known; query-blind and lossy (§II.C).
- **Context Assembly** — harness component that builds the per-turn context feeding the Runtime (Fig. 1).
- **fastcontext** — Microsoft project cited for the 56.2% tool-use-turns / 46.5% main-agent-tokens figures (GPT-5.4 trajectories); also a candidate repo-exploration built-in (§III, §XI).
- **fff** — candidate built-in: path and content search, in-memory index, frequency-ranked, faster than ripgrep in long sessions (§XI).
- **Harness** — the system around the model: explicit state plus the Jev decision points, feeding context assembly and routing (Fig. 1, §I.A).
- **headroom** — candidate built-in: context compressor; native angle is a classifier checking the compression kept the needed facts (§XI).
- **Jev** — TypeSafe's decision model, described from TypeSafe materials as returning typed choices, scores, and noul decisions with probabilities; the decision layer beside the model (§I.A).
- **KV cache** — cached prefix; reuse is cheap, but changing anything early invalidates it and forces reprocessing everything after (§I.B).
- **noul** — a binary yes/no decision returned with a probability (Table I).
- **Off-policy tool calling** — using tools whose usage patterns differ from what the model saw in training; a suspected cause of weak tool selection (§II.B).
- **Policy DSL** — permissions expressed as programmable queries over what is and is not allowed (§IV.A).
- **Recursive language models** — an approach treating agent state as explicit named variables rather than transcript text (attributed to A. Zhang, 2025) (§VIII.B).
- **Routing** — deciding whether a subtask can leave the frontier model; must be priced per context rebuild, not per token (§I, §II.A, §VI).
- **rtk** — candidate built-in: tool-output compressor; native angle is first-party prompts so the model understands it (§XI).
- **Six symptoms** — routing fails, tools crowd context, compaction, sub-agents rare, restarts, batteries debate (§II, Table II).
- **Skills** — capability descriptions that load a short description and defer detail; mean "do this now" (§II.B, §VII, §VIII).
- **Structured skills** — skills that could attach and detach behavior with the condition that triggered them (§VIII.A).
- **Subgoal deduplication** — register a subtask as a subgoal and dedupe against prior subgoals before spawning (§VI.B).
- **Tiered disclosure** — Tier 1 snippets, Tier 2 schema on demand, Tier 3 docs; detail drops from context when done (§VII, Fig. 5).
- **Tyranny of the KV cache** — the notes' name for how cache economics silently shapes append-only agent design (§II).
- **Visibility ladder** — hide / short / long / full, chosen per chunk per query; query-aware compression (§V, Fig. 4).
- **X / Y / Z** — context tokens / generated output tokens / additional tokens read, used in the routing arithmetic (§II.A).
