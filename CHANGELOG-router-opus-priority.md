# Changelog: Router Opus Priority Fixes

**Date:** 2026-02-03
**Commit:** b128b8b `fix(router): maximize opus usage by fixing precedence and criteria`

## Problem

Opus was barely being used (router.log showed 95%+ of requests being sonnet or haiku). Two main issues:

1. **Circular Dependency in Background Task Detection**
   - `isBackgroundTask()` checked `body.model.includes('haiku')`
   - Requests arriving as haiku → detected as background → forced to haiku
   - Self-fulfilling prophecy preventing upstream detection

2. **Wrong Detection Priority Order**
   - Background tasks checked BEFORE plan mode
   - Plan mode detected AFTER already forced to haiku
   - Risk keywords never reached if caught by background check

## Changes Made

### 1. **Remove Circular Dependency** (router.js:122-130)
**Before:**
```javascript
if (body.model && body.model.includes('haiku')) {
  return true;  // ← CIRCULAR
}
```

**After:**
```javascript
return false;  // Only check system prompt for 'subagent' or 'background'
```

### 2. **Reorder Detection Priority** (router.js:225-294)

**New Priority Order:**
```
1. EnterPlanMode (from SSE)          → OPUS
2. Plan Mode Detection              → OPUS
3. Auto-Accept Mode                 → OPUS
4. Risk Keywords                    → OPUS
5. Long Context (>30k tokens)       → OPUS
6. Complexity Keywords (NEW)        → OPUS
7. Architecture + Debugging         → OPUS
8. Background Tasks                 → HAIKU (moved last)
9. Manual Override (#opus/#sonnet)  → CUSTOM
10. Simple Query                     → HAIKU
11. DEFAULT (fallback)              → OPUS (was sonnet)
```

### 3. **Lower Context Threshold** (router.js:32)
```
longContextThreshold: 60000 → 30000
```
Reason: Prevent medium-sized contexts (30-60k) from defaulting to sonnet.

### 4. **Add Complexity Detection Keywords** (router.js:36-41)
```javascript
complexity: /complex|complejo|intricate|sophisticated|system.*wide|architecture|large.*scale|multi[_-]?layer|integration/i,
planning: /plan|design|structure|strategy|approach|metodología|estrategia|arquitectura/i
```

### 5. **Change Default Tier** (router.js:257)
```
tier = 'code' → tier = 'reason'
```
When in doubt, use the more capable model (opus).

## Expected Impact

### Before
- Background tasks: ~100% haiku
- Risk keywords: Rarely detected
- Plan mode: Sometimes sonnet (if caught by background check)
- Large context (>60k): Haiku/sonnet
- Default/ambiguous: Always sonnet

### After
- Background tasks: Haiku ONLY if explicitly marked in system prompt
- Risk keywords: Always opus
- Plan mode: **Always opus** (checked early)
- Large context (>30k): Opus
- Complex tasks: Opus
- Default/ambiguous: **Opus** (safer)

## Files Modified

- `~/.claude/proxy/router.js` (production)
- `examples/proxy/router.js` (version control)

## Next Steps

1. Monitor logs: `tail -f ~/.claude/proxy/router.log | grep Router`
2. Verify plan mode requests use opus
3. Verify risk keywords trigger opus
4. Apply same logic to `proxy-thin.cjs` (MCP server model-router)

## Verification Commands

```bash
# Check logs for usage pattern
grep -o "→ claude-[a-z-]*" ~/.claude/proxy/router.log | sort | uniq -c

# Expected: More "opus" than before

# Test plan mode
echo 'plan mode is active' | grep -E "plan.*mode.*active" && echo "✅ Plan mode detected"

# Monitor new requests
ROUTER_DEBUG=true # Set in environment
tail -f ~/.claude/proxy/router.log
```
