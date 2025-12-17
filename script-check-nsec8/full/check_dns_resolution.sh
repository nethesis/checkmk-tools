#!/usr/bin/env bash

# CheckMK local check - Test risoluzione DNS
echo "<<<dns_resolution>>>"

now_ns() {
    local t
    t=$(date +%s%N 2>/dev/null || true)
    if [[ "$t" =~ ^[0-9]{11,}$ ]]; then
        echo "$t"
    else
        echo $(( $(date +%s) * 1000000000 ))
    fi
}

test_domains=("google.com" "cloudflare.com" "dns.google")
dns_server="127.0.0.1"

successful=0
failed=0
total=${#test_domains[@]}
response_times=()

for domain in "${test_domains[@]}"; do
    start_time=$(now_ns)
    if nslookup "$domain" "$dns_server" 2>/dev/null | grep -qE '^Address: '; then
        end_time=$(now_ns)
        successful=$((successful + 1))
        response_time=$(( (end_time - start_time) / 1000000 ))
        response_times+=("$response_time")
    else
        failed=$((failed + 1))
    fi
done

avg_time=0
if [[ ${#response_times[@]} -gt 0 ]]; then
    for time in "${response_times[@]}"; do
        avg_time=$((avg_time + time))
    done
    avg_time=$((avg_time / ${#response_times[@]}))
fi

if [[ $failed -eq $total ]]; then
    status=2
    status_text="CRITICAL - DNS non risponde"
elif [[ $failed -gt 0 ]]; then
    status=1
    status_text="WARNING - Alcuni test falliti"
elif [[ $avg_time -gt 1000 ]]; then
    status=1
    status_text="WARNING - DNS lento"
else
    status=0
    status_text="OK"
fi

echo "$status DNS_Resolution $status_text - Test: $successful/$total OK, tempo medio: ${avg_time}ms | response_time=${avg_time}ms;500;1000 successful=$successful failed=$failed total=$total avg_time_ms=$avg_time"
