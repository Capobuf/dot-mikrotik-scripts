client
dev tun
remote --PASTE REMOTE PUBLIC IP-- --PASTE PORT--
proto -PASTE PROTO--
nobind
resolv-retry infinite
persist-key
persist-tun
tls-client
remote-cert-tls server
auth-user-pass
verb 4
mute 10
cipher AES-256-CBC
auth SHA1
auth-nocache
route --PASTE REMOTE SUBNET-- 255.255.255.0 --PASTE OVPNGW-- 1

<ca>
---PASTE CERT_EXPORT_CN.CRT---
</ca>

<cert>
---PASTE CERT_EXPORT_USER@CN.CRT---
</cert>

<key>
---PASTE CERT_EXPORT_USER@CN.KEY---
</key>