# Inserisci lo Stesso CN inserito quando hai fatto il Server!
:global CN "INSERT-CN"
:global USERNAME "INSERT-USERNAME"
:global PASSWORD "INSERT-PASSWORD"
:global PUBLICIP "INSERT-IP"

# Genero gli Utenti e i loro Certificati
# Per evitare errori nell'esportazione, inserisci una password +8 char
/ppp secret add \
name="$USERNAME" \
password="$PASSWORD" \
profile=OVPN-Profile \
service=ovpn;

:delay 1s;

## Genero il Certificato per il Client
/certificate add \
name="client-template-to-issue" \
copy-from="client-template" \
common-name="client-$USERNAME@$CN";

/certificate sign client-template-to-issue \
ca="$CN" \
name="$USERNAME@$CN";

:delay 1s;

## Esporto i Certificati e la Chiave per il Client
/certificate export-certificate "$USERNAME@$CN" \
export-passphrase="$PASSWORD" \
file-name="$USERNAME@$CN";

:delay 1s;

## Esporto OVPN File

/interface ovpn-server server \
export-client-configuration ca-certificate="CA.crt" \
client-certificate="$USERNAME@$CN.crt" \
client-cert-key="$USERNAME@$CN.key" \
server-address="$PUBLICIP";

# Rimuovo le Variabili Globali

/system script environment remove USERNAME,PASSWORD,CN,PUBLICIP;
beep;
