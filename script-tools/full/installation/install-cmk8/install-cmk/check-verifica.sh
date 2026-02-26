#!/bin/bash
# check-verifica.sh - Verify CheckMK installation
# Checks that all components are correctly installed and running

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((ERRORS++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo "=== CheckMK Installation Verification ==="
echo ""

# Check OMD
echo "1. Checking OMD..."
if command -v omd &>/dev/null; then
    check_pass "OMD installed"
    
    # Check sites
    if omd sites | grep -q monitoring; then
        check_pass "Site 'monitoring' exists"
        
        # Check site status
        if omd status monitoring | grep -q "running"; then
            check_pass "Site 'monitoring' is running"
        else
            check_fail "Site 'monitoring' is not running"
        fi
    else
        check_fail "Site 'monitoring' not found"
    fi
else
    check_fail "OMD not installed"
fi

echo ""

# Check Apache
echo "2. Checking Apache..."
if systemctl is-active --quiet apache2 || systemctl is-active --quiet httpd; then
    check_pass "Apache is running"
else
    check_fail "Apache is not running"
fi

echo ""

# Check Firewall
echo "3. Checking Firewall..."
if command -v ufw &>/dev/null; then
    if ufw status | grep -q "Status: active"; then
        check_pass "UFW is active"
        
        if ufw status | grep -q "80/tcp"; then
            check_pass "HTTP port 80 is open"
        else
            check_warn "HTTP port 80 may not be open"
        fi
        
        if ufw status | grep -q "443/tcp"; then
            check_pass "HTTPS port 443 is open"
        else
            check_warn "HTTPS port 443 may not be open"
        fi
    else
        check_warn "UFW is inactive"
    fi
fi

echo ""

# Check Fail2Ban
echo "4. Checking Fail2Ban..."
if systemctl is-active --quiet fail2ban; then
    check_pass "Fail2Ban is running"
else
    check_warn "Fail2Ban is not running"
fi

echo ""

# Check SSL Certificate
echo "5. Checking SSL..."
if [[ -d /etc/letsencrypt/live ]]; then
    check_pass "Let's Encrypt directory exists"
else
    check_warn "No Let's Encrypt certificates found"
fi

echo ""

# Check web access
echo "6. Checking Web Access..."
HOSTNAME_IP=$(hostname -I | awk '{print $1}')

if curl -s -o /dev/null -w "%{http_code}" "http://localhost/monitoring/" | grep -q "200\|301\|302"; then
    check_pass "CheckMK web interface accessible locally"
else
    check_fail "CheckMK web interface not accessible"
fi

echo ""
echo "==================================="

if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}✓ All checks passed${NC}"
    echo ""
    echo "Access CheckMK at: http://${HOSTNAME_IP}/monitoring"
    exit 0
else
    echo -e "${RED}✗ ${ERRORS} check(s) failed${NC}"
    echo ""
    echo "Review the errors above and fix any issues"
    exit 1
fi
