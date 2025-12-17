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
