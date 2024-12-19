:global DNS "10.10.60.1"
:global L2GW "10.10.60.1"
:global POOL "10.10.60.100-10.10.60.110"
:global USER "user"
:global PSWD "password"
:global PSK "presharedkey"

#Creo il Pool
/ip pool
add name="l2tp_pool()" ranges=$POOL

#Creo il Profilo
/ppp profile
add dns-server=$DNS local-address=$L2GW name=L2TP-PROFILE only-one=no remote-address="l2tp_pool()" use-encryption=yes wins-server=$L2GW

#Creo il Server L2TP
/interface l2tp-server server
set default-profile=L2TP-PROFILE enabled=yes use-ipsec=required ipsec-secret=$PSK

#Aggiungo il Secret
/ppp secret
add name=$USER password="$PSWD" profile=L2TP-PROFILE service=l2tp

#Configuro il Firewall
/ip firewall filter
add action=accept chain=input comment="L2TP/IPSEC IKE IN" dst-port=500 protocol=udp
add action=accept chain=input comment="L2TP/IPSEC NAT-T IN" dst-port=4500 protocol=udp
add action=accept chain=input comment="L2TP IN" dst-port=1701 protocol=udp
add action=reject chain=input comment="DENY L2TP W/OUT IPSEC" dst-port=1701 ipsec-policy=in,none protocol=udp reject-with=icmp-admin-prohibited
/
/beep
/
