
#!/bin/bash
/bin/bash
# ============================================
# Installazione e Configurazione Postfix Smarthost
# ============================================set -euo pipefail
echo ">>> Installazione Postfix"apt update -qqapt install -y postfix mailutils libsasl2-modules
echo ">>> Configurazione Postfix come Smarthost"read -r -p "Inserisci SMTP relay (es. smtp.gmail.com): " RELAYHOSTread -r -p "Inserisci porta SMTP (default 587): " 
RELAYPORTRELAYPORT=${RELAYPORT:-587}read -r -p "Inserisci utente SMTP: " SMTP_USERset +o historyread -s -p "Inserisci password SMTP: " SMTP_PASSset -o historyechoread -r -p "Inserisci indirizzo email di test: " TEST_EMAILpostconf -e "relayhost = [$RELAYHOST]:$RELAYPORT"postconf -e "smtp_use_tls = yes"postconf -e "smtp_sasl_auth_enable = yes"postconf -e "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd"postconf -e "smtp_sasl_security_options = noanonymous"postconf -e "smtp_sasl_tls_security_options = noanonymous"
echo "[$RELAYHOST]:$RELAYPORT $SMTP_USER:$SMTP_PASS" > /etc/postfix/sasl_passwdchmod 600 /etc/postfix/sasl_passwdpostmap /etc/postfix/sasl_passwdsystemctl enable postfixsystemctl restart postfix
echo ">>> Test invio email..."
echo "Test Postfix Smarthost su $(hostname)" | mail -s "Checkmk Smarthost Test" "$TEST_EMAIL"
echo "============================================"
echo " Postfix installato e configurato come Smarthost"
echo " Relayhost: $RELAYHOST"
echo " Porta: $RELAYPORT"
echo " Utente: $SMTP_USER"
echo " Email di test: $TEST_EMAIL"
echo "============================================"
