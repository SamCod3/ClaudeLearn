# Session Storage Monitoring & Verification

**Date**: 2026-02-03
**Status**: Ready for monitoring

---

## How to Verify the 3-Layer System is Working

### 1. Check Backup Directory

After `/exit`, verify that JSONL is backed up:

```bash
# Check what's in the backup directory
ls -lah ~/.claude-backup-sessions/ClaudeLearn/

# Should see: {SESSION_ID}.jsonl files
# Example: 507c0f9b-c179-4271-b022-38808207057c.jsonl
```

### 2. Check File Sizes Match

Verify Layer 3 copy verification is working:

```bash
# Compare sizes of source vs backup
SRC_SIZE=$(stat -c%s ~/.claude/projects/-Users-sambler-DEV-ClaudeCode-ClaudeLearn/{SESSION_ID}.jsonl)
DST_SIZE=$(stat -c%s ~/.claude-backup-sessions/ClaudeLearn/{SESSION_ID}.jsonl)

echo "Source: $SRC_SIZE bytes"
echo "Backup: $DST_SIZE bytes"
# Should be equal ✅
```

### 3. Check Logs for Retry Logic

If MCP times out, look for retry logs:

```bash
# Check session-save logs (if available)
grep -i "🔄 Retrying\|⏱️ Timeout\|FALLBACK" ~/.claude/hooks/*.log 2>/dev/null || echo "No logs yet"

# Expected patterns:
# - "[session-save] 📝 Attempt 1/2: Calling session_save..."
# - "[session-save] ⏱️ Timeout on attempt 1/2"
# - "[session-save] 🔄 Retrying in 1 second..."
# - "[session-save] ✅ JSONL backed up (XXXXX bytes)"
```

### 4. Manual Test: Simulate Session

Create a simple session and verify backup:

```bash
# 1. Open Claude Code
claude-code /some/project

# 2. Do something (edit a file, read a file)

# 3. /exit

# 4. Verify backup
ls -la ~/.claude-backup-sessions/ClaudeLearn/ | tail -1
# Should show your session JSONL file
```

---

## Monitoring Checklist

- [ ] After next `/exit`, check `~/.claude-backup-sessions/ClaudeLearn/` has new JSONL
- [ ] Run `test-session-backup.sh` regularly to verify all 3 layers
- [ ] Monitor logs for any "❌ Failed after 2 attempts" errors
- [ ] Verify no sessions are lost (check `/continue-dev` output)
- [ ] Compare backup vs original JSONL sizes (should match)

---

## Troubleshooting

### Backup directory is empty

**Problem**: `~/.claude-backup-sessions/ClaudeLearn/` exists but no files

**Cause**: pre-session-save-backup.sh may not be registered in hooks

**Fix**:
```bash
# Check if hook is executable
ls -lh ~/.claude/hooks/pre-session-save-backup.sh
# Should have +x permission

# Verify hook is called (check if session-end-save.sh calls it)
grep "pre-session-save-backup" ~/.claude/hooks/session-end-save.sh
```

### Size mismatch in verification

**Problem**: Copy verification fails (srcSize != dstSize)

**Cause**: Disk full, permission denied, or I/O error

**Fix**:
```bash
# Check disk space
df -h ~/.claude-backup-sessions/
df -h ~/.claude-backup/

# Check permissions
ls -ld ~/.claude-backup-sessions/
chmod 755 ~/.claude-backup-sessions/ 2>/dev/null
```

### Retry logic not triggering

**Problem**: No "🔄 Retrying" messages in logs

**Cause**: MCP is not timing out, or logs are not captured

**Fix**:
```bash
# Check if call-mcp-session-save.js has retry logic
grep "maxAttempts" ~/.claude/hooks/call-mcp-session-save.js

# If missing, re-apply the changes from implementation-summary.md
```

---

## Performance Baseline

- **Layer 1 (pre-backup)**: <100ms (file copy)
- **Layer 2 (MCP call)**: ~1-5s (normal), ~10s+ (timeout → retry)
- **Layer 3 (validation)**: <50ms (size check)

**Total overhead**: ~5-6s per session (includes MCP initialization)

---

## Expected Behavior

### Normal flow
```
SessionEnd Hook
  → pre-session-save-backup.sh ✅ (100ms, JSONL copied)
  → call-mcp-session-save.js ✅ (2s, MCP successful)
  → session-save.ts ✅ (validate, index in DB)
Result: Session saved in all 3 layers ✅
```

### Timeout + Retry flow
```
SessionEnd Hook
  → pre-session-save-backup.sh ✅ (100ms, JSONL copied)
  → call-mcp-session-save.js [Attempt 1] ⏱️ (10s timeout)
  → call-mcp-session-save.js [Attempt 2] ✅ (2s, MCP successful)
  → session-save.ts ✅ (validate, index in DB)
Result: Session saved (retry recovered from timeout) ✅
```

### MCP crash flow
```
SessionEnd Hook
  → pre-session-save-backup.sh ✅ (100ms, JSONL copied ← SAVED HERE)
  → call-mcp-session-save.js ❌ (MCP crashed)
Result: Conversation is in ~/.claude-backup-sessions/ ✅ (fallback safe)
```

---

## Next Steps

1. ✅ Implementation complete
2. ✅ Testing passed
3. ⏳ Monitor next 5 sessions for backup verification
4. ⏳ Check logs for any timeout/retry events
5. ⏳ If all clear, update status to "Production Ready"

---

## Files to Monitor

```
~/.claude-backup-sessions/           ← Layer 1 backups (check file count)
~/.claude-backup/                    ← Layer 3 backups (check file count)
~/.claude/hooks/call-mcp-session-save.js.log  ← Logs (if enabled)
```

---

## Questions to Answer

After 1 week of monitoring:

- [ ] Did any session JSONLs get backed up? (Check file count)
- [ ] Did retry logic trigger? (Check logs for "🔄 Retrying")
- [ ] Were any sessions lost? (Check /continue-dev consistency)
- [ ] Are backups accumulating? (Du -sh ~/.claude-backup-sessions/)
- [ ] Performance impact acceptable? (Session times still normal)

