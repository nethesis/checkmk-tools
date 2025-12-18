#!/usr/bin/env bash
set -euo pipefail

echo "ERROR: this script was quarantined because it was syntactically broken." >&2
echo "A copy of the previous content was saved next to this file." >&2
exit 1

: <<'CORRUPTED_623cbe31add346d29b3b410d70dbd518'
#!/bin/bashsource .env
TITLE="$1"
DESCRIPTION="$2"
PRIORITY_ITA="$3"
# Converti priorit├á italiana in inglesecase "${PRIORITY_ITA,,}" in  bassa)    
PRIORITY="low" ;;  media)    
PRIORITY="normal" ;;  alta)     
PRIORITY="high" ;;  critica)  
PRIORITY="critical" ;;  *)        
PRIORITY="normal" ;;esac
echo "­ƒÄ½ Creazione ticket con priorit├á: $PRIORITY_ITA ÔåÆ $PRIORITY"
echo ""./ydea-toolkit.sh create "$TITLE" "$DESCRIPTION" "$PRIORITY"

CORRUPTED_623cbe31add346d29b3b410d70dbd518

