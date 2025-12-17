# ✅ CheckMK Agent URL - CORRECTED!

**Date:** 2025-11-07 (Final Fix)  
**Status:** ✅ FIXED WITH CORRECT URL

---

## Issue Fixed

The CheckMK Agent download URL was incorrect. The proper URL is:
```
https://monitoring.nethlab.it/monitoring/check_mk/agents/windows/check_mk_agent.msi
```

### What Was Wrong

Before:
- ❌ Used versioned filename: `check-mk-agent-2.4.0p14-1_all.msi`
- ❌ Incorrect path structure
- ❌ URL construction was wrong

### What's Fixed Now

After:
- ✅ Uses generic filename: `check_mk_agent.msi`
- ✅ Correct path: `/monitoring/check_mk/agents/windows/`
- ✅ Works with your monitoring server

---

## Changes Made

### File: `script-tools/install-agent-interactive.ps1`

**Line 23-24 (URLs):**
```powershell
$CHECKMK_MSI_URLS = @(
    "https://monitoring.nethlab.it/monitoring/check_mk/agents/windows/check_mk_agent.msi",  # ✅ PRIMARY
    "https://download.checkmk.com/checkmk/$CHECKMK_VERSION/check-mk-agent-$CHECKMK_VERSION-1_all.msi"  # Fallback
)
```

**Line 206 (File name):**
```powershell
$msiFile = "$DOWNLOAD_DIR\check_mk_agent.msi"  # ✅ CORRECTED
```

---

## How It Works Now

1. **Primary URL** (from your local server):
   ```
   https://monitoring.nethlab.it/monitoring/check_mk/agents/windows/check_mk_agent.msi
   ```

2. **Fallback URL** (optional - if primary fails):
   ```
   https://download.checkmk.com/checkmk/2.4.0p14/check-mk-agent-2.4.0p14-1_all.msi
   ```

3. **Script tries** primary first
4. **If it fails**, automatically tries fallback
5. **Shows progress** as it downloads

---

## Testing

Run the script again:

```powershell
cd 'C:\Users\Marzio\Desktop\CheckMK\Script\script-tools'
.\install-agent-interactive.ps1
```

**Expected output:**
```
[*] Download CheckMK Agent v2.4.0p14...
    Tentativo download da: https://monitoring.nethlab.it/monitoring/check_mk/agents/windows/check_mk_agent.msi
    [OK] Download completato (X.XX MB)
```

---

## Commit

```
3911469 - fix: Use correct CheckMK Agent URL from monitoring.nethlab.it
```

---

## Status

✅ **URL:** CORRECTED  
✅ **Syntax:** VALID  
✅ **Committed:** YES  
✅ **Pushed:** YES  

🟢 **Ready to test!**

The script will now download the correct CheckMK Agent MSI from your monitoring server.
