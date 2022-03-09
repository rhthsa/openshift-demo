# Deployment Strategy with OpenShift Route
<!-- TOC -->

- [Deployment Strategy with OpenShift Route](#deployment-strategy-with-openshift-route)
  - [Application Deployment](#application-deployment)
  - [Blue/Green Deployment](#bluegreen-deployment)
  - [Canary Deployment](#canary-deployment)
  - [Restrict TLS to v1.2](#restrict-tls-to-v12)
    - [Test TLS/SSL](#test-tlsssl)
  - [Access Log](#access-log)
    - [Verify Access Log](#verify-access-log)
      - [Sidecar](#sidecar)
      - [Internal ElasticSearch](#internal-elasticsearch)

<!-- /TOC -->
## Application Deployment
Deploy 2 version of frontend app. Each deployment and service use label **app** and **version** for select each version. 
Initial Route will routing all traffic to v1.

- Deploy frontend v1 and v2 and create route [frontend.yaml](manifests/frontend.yaml)
  
  ```bash
  oc apply -f manifests/frontend.yaml -n project1
  ```

## Blue/Green Deployment
- Test Route
  
  ```bash
  FRONTEND_URL=https://$(oc get route frontend -n project1 -o jsonpath='{.spec.host}')
  while [ 1 ];
  do
     curl -k $FRONTEND_URL/version
     echo
     sleep 1
  done
  ```

- Use another terminal to patch route to frontend v2
  
  ```bash
  oc patch route frontend  -p '{"spec":{"to":{"name":"frontend-v2"}}}' -n project1
  ```

- Check output from cURL that response is from frontend-v2
- Set route back to v1
  
  ```bash
  oc patch route frontend  -p '{"spec":{"to":{"name":"frontend-v1"}}}' -n project1
  ```

- Check output from cURL that response is from frontend-v1

## Canary Deployment
- Apply route for Canary deployment to v1 and v2 with 80% and 20% ratio [route-with-alternate-backend.yaml](manifests/route-with-alternate-backend.yaml)
  
  ```bash
  oc apply -f manifests/route-with-alternate-backend.yaml -n project1
  ```

- Call frontend for 10 times. You will get 8 responses from v1 and 2 responses from v2
  
  ```bash
  FRONTEND_URL=https://$(oc get route frontend -n project1 -o jsonpath='{.spec.host}')
  COUNT=0
  while [ $COUNT -lt 10 ];
  do
    curl -k $FRONTEND_URL/version
    echo
    sleep .2
    COUNT=$(expr $COUNT + 1)
  done
  ```

- Update weight to 60% and 40%
  
  ```bash
  oc patch route frontend  -p '{"spec":{"to":{"weight":60}}}' -n project1 
  oc patch route frontend --type='json' -p='[{"op":"replace","path":"/spec/alternateBackends/0/weight","value":40}]' -n project1 
  ```

- Re-run previous bash script to loop frontend. This times you will get 6 responses from v1 and 4 responses from v2
  
## Restrict TLS to v1.2
- Check default ingresscontroller by run command or use OpenShift Web Admin Console

```bash
oc edit ingresscontroller default -n openshift-ingress-operator
```

Use Web Admin Console to search for ingressscontroller and select default

![](images/ingress-controller-01.png)


- Minimum TLS version can be specified by attribute **minTLSVersion**

![](images/ingress-controller-02.png)

- Also test with custom profile, edit `tlsProfile:` and click **Save**

```yaml
spec:
  replicas: 2
  tlsSecurityProfile:
    type: Custom
    custom:
      ciphers:
        - ECDHE-ECDSA-AES128-GCM-SHA256
        - ECDHE-RSA-AES128-GCM-SHA256
      minTLSVersion: VersionTLS12
```

### Test TLS/SSL

To test TLS/SSL encryption enabled on OpenShift ingresscontroller, use `https://testssl.sh/` testssl.ssh tool to run report for Ingress VIP support of TLS/SSL ciphers and protocols

Run the test

```bash
docker run --rm -ti drwetter/testssl.sh https://frontend-project1.apps.ocp01.example.com
```

Sample results

From OpenShift ingress (default tls profile)

```bash
 Start 2020-12-30 03:37:42        -->> 198.18.1.202:443 (frontend-project1.apps.ocp01.example.com) <<--

 rDNS (198.18.1.202):    .apps.ocp01.example.com.
 Service detected:       HTTP


 Testing protocols via sockets except NPN+ALPN

 SSLv2      not offered (OK)
 SSLv3      not offered (OK)
 TLS 1      not offered
 TLS 1.1    not offered
 TLS 1.2    offered (OK)
 TLS 1.3    offered (OK): final
 NPN/SPDY   not offered
 ALPN/HTTP2 not offered

 Testing cipher categories

 NULL ciphers (no encryption)                      not offered (OK)
 Anonymous NULL Ciphers (no authentication)        not offered (OK)
 Export ciphers (w/o ADH+NULL)                     not offered (OK)
 LOW: 64 Bit + DES, RC[2,4], MD5 (w/o export)      not offered (OK)
 Triple DES Ciphers / IDEA                         not offered
 Obsoleted CBC ciphers (AES, ARIA etc.)            not offered
 Strong encryption (AEAD ciphers) with no FS       not offered
 Forward Secrecy strong encryption (AEAD ciphers)  offered (OK)


 Testing server's cipher preferences

 Has server cipher order?     yes (OK) -- TLS 1.3 and below
 Negotiated protocol          TLSv1.3
 Negotiated cipher            TLS_AES_256_GCM_SHA384, 253 bit ECDH (X25519)
 Cipher per protocol

Hexcode  Cipher Suite Name (OpenSSL)       KeyExch.   Encryption  Bits     Cipher Suite Name (IANA/RFC)
-----------------------------------------------------------------------------------------------------------------------------
SSLv2
 -
SSLv3
 -
TLSv1
 -
TLSv1.1
 -
TLSv1.2 (server order)
 xc02f   ECDHE-RSA-AES128-GCM-SHA256       ECDH 253   AESGCM      128      TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
 xc030   ECDHE-RSA-AES256-GCM-SHA384       ECDH 253   AESGCM      256      TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
 xcca8   ECDHE-RSA-CHACHA20-POLY1305       ECDH 253   ChaCha20    256      TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256
 x9e     DHE-RSA-AES128-GCM-SHA256         DH 2048    AESGCM      128      TLS_DHE_RSA_WITH_AES_128_GCM_SHA256
 x9f     DHE-RSA-AES256-GCM-SHA384         DH 2048    AESGCM      256      TLS_DHE_RSA_WITH_AES_256_GCM_SHA384
TLSv1.3 (server order)
 x1302   TLS_AES_256_GCM_SHA384            ECDH 253   AESGCM      256      TLS_AES_256_GCM_SHA384
 x1303   TLS_CHACHA20_POLY1305_SHA256      ECDH 253   ChaCha20    256      TLS_CHACHA20_POLY1305_SHA256
 x1301   TLS_AES_128_GCM_SHA256            ECDH 253   AESGCM      128      TLS_AES_128_GCM_SHA256
 x1304   TLS_AES_128_CCM_SHA256            ECDH 253   AESCCM      128      TLS_AES_128_CCM_SHA256


 Testing robust forward secrecy (FS) -- omitting Null Authentication/Encryption, 3DES, RC4

 FS is offered (OK)           TLS_AES_256_GCM_SHA384 TLS_CHACHA20_POLY1305_SHA256 ECDHE-RSA-AES256-GCM-SHA384
                              DHE-RSA-AES256-GCM-SHA384 ECDHE-RSA-CHACHA20-POLY1305 TLS_AES_128_GCM_SHA256
                              TLS_AES_128_CCM_SHA256 ECDHE-RSA-AES128-GCM-SHA256 DHE-RSA-AES128-GCM-SHA256
 Elliptic curves offered:     prime256v1 secp384r1 secp521r1 X25519 X448
 DH group offered:            HAProxy (2048 bits)

 Testing server defaults (Server Hello)

 TLS extensions (standard)    "renegotiation info/#65281" "server name/#0" "EC point formats/#11"
                              "session ticket/#35" "supported versions/#43" "key share/#51"
                              "supported_groups/#10" "max fragment length/#1" "extended master secret/#23"
 Session Ticket RFC 5077 hint 7200 seconds, session tickets keys seems to be rotated < daily
 SSL Session ID support       yes
 Session Resumption           Tickets: yes, ID: yes
 TLS clock skew               Random values, no fingerprinting possible
 Signature Algorithm          SHA256 with RSA
 Server key size              RSA 2048 bits (exponent is 65537)
 Server key usage             Digital Signature, Key Encipherment
 Server extended key usage    TLS Web Server Authentication
 Serial / Fingerprints        590C2A8BF166D6DE / SHA1 D3A0E8768DA3E8CF037EDB51A28189090356486B
                              SHA256 162934C54D4B3A01007D20809FC1BF7C0E37C476FB508C170F0AE6017C16A1C6
 Common Name (CN)             *.apps.ocp01.example.com
 subjectAltName (SAN)         *.apps.ocp01.example.com
 Trust (hostname)             Ok via SAN wildcard and CN wildcard (same w/o SNI)
 Chain of trust               NOT ok (self signed CA in chain)
 EV cert (experimental)       no
 Certificate Validity (UTC)   728 >= 60 days (2020-12-28 05:07 --> 2022-12-28 05:07)
                              > 398 days issued after 2020/09/01 is too long
 ETS/"eTLS", visibility info  not present
 Certificate Revocation List  --
 OCSP URI                     --
                              NOT ok -- neither CRL nor OCSP URI provided
 OCSP stapling                not offered
 OCSP must staple extension   --
 DNS CAA RR (experimental)    not offered
 Certificate Transparency     --
 Certificates provided        2
 Issuer                       ingress-operator@1609132063
 Intermediate cert validity   #1: ok > 40 days (2022-12-28 05:07). ingress-operator@1609132063 <-- ingress-operator@1609132063
 Intermediate Bad OCSP (exp.) Ok


 Testing HTTP header response @ "/"

 HTTP Status Code             200 OK
 HTTP clock skew              0 sec from localtime
 Strict Transport Security    not offered
 Public Key Pinning           --
 Server banner                (no "Server" line in header, interesting!)
 Application banner           X-Powered-By: Express
 Cookie(s)                    1 issued: 1/1 secure, 1/1 HttpOnly
 Security headers             Cache-Control: private
 Reverse Proxy banner         --


 Testing vulnerabilities

 Heartbleed (CVE-2014-0160)                not vulnerable (OK), no heartbeat extension
 CCS (CVE-2014-0224)                       not vulnerable (OK)
 Ticketbleed (CVE-2016-9244), experiment.  not vulnerable (OK)
 ROBOT                                     Server does not support any cipher suites that use RSA key transport
 Secure Renegotiation (RFC 5746)           supported (OK)
 Secure Client-Initiated Renegotiation     not vulnerable (OK)
 CRIME, TLS (CVE-2012-4929)                not vulnerable (OK)
 BREACH (CVE-2013-3587)                    no gzip/deflate/compress/br HTTP compression (OK)  - only supplied "/" tested
 POODLE, SSL (CVE-2014-3566)               not vulnerable (OK), no SSLv3 support
 TLS_FALLBACK_SCSV (RFC 7507)              No fallback possible (OK), no protocol below TLS 1.2 offered
 SWEET32 (CVE-2016-2183, CVE-2016-6329)    not vulnerable (OK)
 FREAK (CVE-2015-0204)                     not vulnerable (OK)
 DROWN (CVE-2016-0800, CVE-2016-0703)      not vulnerable on this host and port (OK)
                                           make sure you don't use this certificate elsewhere with SSLv2 enabled services
                                           https://censys.io/ipv4?q=162934C54D4B3A01007D20809FC1BF7C0E37C476FB508C170F0AE6017C16A1C6 could help you to find out
 LOGJAM (CVE-2015-4000), experimental      common prime with 2048 bits detected: HAProxy (2048 bits),
                                           but no DH EXPORT ciphers
 BEAST (CVE-2011-3389)                     not vulnerable (OK), no SSL3 or TLS1
 LUCKY13 (CVE-2013-0169), experimental     not vulnerable (OK)
 Winshock (CVE-2014-6321), experimental    not vulnerable (OK)
 RC4 (CVE-2013-2566, CVE-2015-2808)        no RC4 ciphers detected (OK)


 Running client simulations (HTTP) via sockets

 Browser                      Protocol  Cipher Suite Name (OpenSSL)       Forward Secrecy
------------------------------------------------------------------------------------------------
 Android 4.4.2                TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       256 bit ECDH (P-256)
 Android 5.0.0                TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       256 bit ECDH (P-256)
 Android 6.0                  TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       256 bit ECDH (P-256)
 Android 7.0 (native)         TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       256 bit ECDH (P-256)
 Android 8.1 (native)         TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       253 bit ECDH (X25519)
 Android 9.0 (native)         TLSv1.3   TLS_AES_256_GCM_SHA384            253 bit ECDH (X25519)
 Android 10.0 (native)        TLSv1.3   TLS_AES_256_GCM_SHA384            253 bit ECDH (X25519)
 Chrome 74 (Win 10)           TLSv1.3   TLS_AES_256_GCM_SHA384            253 bit ECDH (X25519)
 Chrome 79 (Win 10)           TLSv1.3   TLS_AES_256_GCM_SHA384            253 bit ECDH (X25519)
 Firefox 66 (Win 8.1/10)      TLSv1.3   TLS_AES_256_GCM_SHA384            253 bit ECDH (X25519)
 Firefox 71 (Win 10)          TLSv1.3   TLS_AES_256_GCM_SHA384            253 bit ECDH (X25519)
 IE 6 XP                      No connection
 IE 8 Win 7                   No connection
 IE 8 XP                      No connection
 IE 11 Win 7                  TLSv1.2   DHE-RSA-AES128-GCM-SHA256         2048 bit DH
 IE 11 Win 8.1                TLSv1.2   DHE-RSA-AES128-GCM-SHA256         2048 bit DH
 IE 11 Win Phone 8.1          No connection
 IE 11 Win 10                 TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       256 bit ECDH (P-256)
 Edge 15 Win 10               TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       253 bit ECDH (X25519)
 Edge 17 (Win 10)             TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       253 bit ECDH (X25519)
 Opera 66 (Win 10)            TLSv1.3   TLS_AES_256_GCM_SHA384            253 bit ECDH (X25519)
 Safari 9 iOS 9               TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       256 bit ECDH (P-256)
 Safari 9 OS X 10.11          TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       256 bit ECDH (P-256)
 Safari 10 OS X 10.12         TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       256 bit ECDH (P-256)
 Safari 12.1 (iOS 12.2)       TLSv1.3   TLS_CHACHA20_POLY1305_SHA256      253 bit ECDH (X25519)
 Safari 13.0 (macOS 10.14.6)  TLSv1.3   TLS_CHACHA20_POLY1305_SHA256      253 bit ECDH (X25519)
 Apple ATS 9 iOS 9            TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       256 bit ECDH (P-256)
 Java 6u45                    No connection
 Java 7u25                    No connection
 Java 8u161                   TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       256 bit ECDH (P-256)
 Java 11.0.2 (OpenJDK)        TLSv1.3   TLS_AES_256_GCM_SHA384            256 bit ECDH (P-256)
 Java 12.0.1 (OpenJDK)        TLSv1.3   TLS_AES_256_GCM_SHA384            256 bit ECDH (P-256)
 OpenSSL 1.0.2e               TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       256 bit ECDH (P-256)
 OpenSSL 1.1.0l (Debian)      TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       253 bit ECDH (X25519)
 OpenSSL 1.1.1d (Debian)      TLSv1.3   TLS_AES_256_GCM_SHA384            253 bit ECDH (X25519)
 Thunderbird (68.3)           TLSv1.3   TLS_AES_256_GCM_SHA384            253 bit ECDH (X25519)


 Rating (experimental)

 Rating specs (not complete)  SSL Labs's 'SSL Server Rating Guide' (version 2009q from 2020-01-30)
 Specification documentation  https://github.com/ssllabs/research/wiki/SSL-Server-Rating-Guide
 Protocol Support (weighted)  0 (0)
 Key Exchange     (weighted)  0 (0)
 Cipher Strength  (weighted)  0 (0)
 Final Score                  0
 Overall Grade                T
 Grade cap reasons            Grade capped to T. Issues with the chain of trust (self signed CA in chain)
                              Grade capped to A. HSTS is not offered

 Done 2020-12-30 03:39:20 [ 100s] -->> 198.18.1.202:443 (frontend-project1.apps.ocp01.example.com) <<--
```

From OpenShift ingress (default tls profile)

```log
 Start 2020-12-30 03:46:29        -->> 198.18.1.202:443 (frontend-project1.apps.ocp01.example.com) <<--

 rDNS (198.18.1.202):    --
 Service detected:       HTTP


 Testing protocols via sockets except NPN+ALPN

 SSLv2      not offered (OK)
 SSLv3      not offered (OK)
 TLS 1      not offered
 TLS 1.1    not offered
 TLS 1.2    offered (OK)
 TLS 1.3    offered (OK): final
 NPN/SPDY   not offered
 ALPN/HTTP2 not offered

 Testing cipher categories

 NULL ciphers (no encryption)                      not offered (OK)
 Anonymous NULL Ciphers (no authentication)        not offered (OK)
 Export ciphers (w/o ADH+NULL)                     not offered (OK)
 LOW: 64 Bit + DES, RC[2,4], MD5 (w/o export)      not offered (OK)
 Triple DES Ciphers / IDEA                         not offered
 Obsoleted CBC ciphers (AES, ARIA etc.)            not offered
 Strong encryption (AEAD ciphers) with no FS       not offered
 Forward Secrecy strong encryption (AEAD ciphers)  offered (OK)


 Testing server's cipher preferences

 Has server cipher order?     yes (OK) -- TLS 1.3 and below
 Negotiated protocol          TLSv1.3
 Negotiated cipher            TLS_AES_256_GCM_SHA384, 253 bit ECDH (X25519)
 Cipher per protocol

Hexcode  Cipher Suite Name (OpenSSL)       KeyExch.   Encryption  Bits     Cipher Suite Name (IANA/RFC)
----------------------------------------------------------------------------------------------------------------                                                        -------------
SSLv2
 -
SSLv3
 -
TLSv1
 -
TLSv1.1
 -
TLSv1.2 (server order)
 xc02f   ECDHE-RSA-AES128-GCM-SHA256       ECDH 256   AESGCM      128      TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256                                                        
TLSv1.3 (server order)
 x1302   TLS_AES_256_GCM_SHA384            ECDH 253   AESGCM      256      TLS_AES_256_GCM_SHA384
 x1303   TLS_CHACHA20_POLY1305_SHA256      ECDH 253   ChaCha20    256      TLS_CHACHA20_POLY1305_SHA256
 x1301   TLS_AES_128_GCM_SHA256            ECDH 253   AESGCM      128      TLS_AES_128_GCM_SHA256
 x1304   TLS_AES_128_CCM_SHA256            ECDH 253   AESCCM      128      TLS_AES_128_CCM_SHA256


 Testing robust forward secrecy (FS) -- omitting Null Authentication/Encryption, 3DES, RC4

 FS is offered (OK)           TLS_AES_256_GCM_SHA384 TLS_CHACHA20_POLY1305_SHA256 TLS_AES_128_GCM_SHA256
                              TLS_AES_128_CCM_SHA256 ECDHE-RSA-AES128-GCM-SHA256
 Elliptic curves offered:     prime256v1 secp384r1 secp521r1 X25519 X448


 Testing server defaults (Server Hello)

 TLS extensions (standard)    "renegotiation info/#65281" "server name/#0" "EC point formats/#11"
                              "session ticket/#35" "supported versions/#43" "key share/#51"
                              "supported_groups/#10" "max fragment length/#1" "extended master secret/#23"
 Session Ticket RFC 5077 hint 7200 seconds, session tickets keys seems to be rotated < daily
 SSL Session ID support       yes
 Session Resumption           Tickets: yes, ID: yes
 TLS clock skew               Random values, no fingerprinting possible
 Signature Algorithm          SHA256 with RSA
 Server key size              RSA 2048 bits (exponent is 65537)
 Server key usage             Digital Signature, Key Encipherment
 Server extended key usage    TLS Web Server Authentication
 Serial / Fingerprints        590C2A8BF166D6DE / SHA1 D3A0E8768DA3E8CF037EDB51A28189090356486B
                              SHA256 162934C54D4B3A01007D20809FC1BF7C0E37C476FB508C170F0AE6017C16A1C6
 Common Name (CN)             *.apps.ocp01.example.com
 subjectAltName (SAN)         *.apps.ocp01.example.com
 Trust (hostname)             Ok via SAN wildcard and CN wildcard (same w/o SNI)
 Chain of trust               NOT ok (self signed CA in chain)
 EV cert (experimental)       no
 Certificate Validity (UTC)   728 >= 60 days (2020-12-28 05:07 --> 2022-12-28 05:07)
                              > 398 days issued after 2020/09/01 is too long
 ETS/"eTLS", visibility info  not present
 Certificate Revocation List  --
 OCSP URI                     --
                              NOT ok -- neither CRL nor OCSP URI provided
 OCSP stapling                not offered
 OCSP must staple extension   --
 DNS CAA RR (experimental)    not offered
 Certificate Transparency     --
 Certificates provided        2
 Issuer                       ingress-operator@1609132063
 Intermediate cert validity   #1: ok > 40 days (2022-12-28 05:07). ingress-operator@1609132063 <-- ingress-operator@1609132063
 Intermediate Bad OCSP (exp.) Ok


 Testing HTTP header response @ "/"

 HTTP Status Code             200 OK
 HTTP clock skew              0 sec from localtime
 Strict Transport Security    not offered
 Public Key Pinning           --
 Server banner                (no "Server" line in header, interesting!)
 Application banner           X-Powered-By: Express
 Cookie(s)                    1 issued: 1/1 secure, 1/1 HttpOnly
 Security headers             Cache-Control: private
 Reverse Proxy banner         --


 Testing vulnerabilities

 Heartbleed (CVE-2014-0160)                not vulnerable (OK), no heartbeat extension
 CCS (CVE-2014-0224)                       not vulnerable (OK)
 Ticketbleed (CVE-2016-9244), experiment.  not vulnerable (OK)
 ROBOT                                     Server does not support any cipher suites that use RSA key transport
 Secure Renegotiation (RFC 5746)           supported (OK)
 Secure Client-Initiated Renegotiation     not vulnerable (OK)
 CRIME, TLS (CVE-2012-4929)                not vulnerable (OK)
 BREACH (CVE-2013-3587)                    no gzip/deflate/compress/br HTTP compression (OK)  - only supplied "/" tested
 POODLE, SSL (CVE-2014-3566)               not vulnerable (OK), no SSLv3 support
 TLS_FALLBACK_SCSV (RFC 7507)              No fallback possible (OK), no protocol below TLS 1.2 offered
 SWEET32 (CVE-2016-2183, CVE-2016-6329)    not vulnerable (OK)
 FREAK (CVE-2015-0204)                     not vulnerable (OK)
 DROWN (CVE-2016-0800, CVE-2016-0703)      not vulnerable on this host and port (OK)
                                           make sure you don't use this certificate elsewhere with SSLv2 enabled services
                                           https://censys.io/ipv4?q=162934C54D4B3A01007D20809FC1BF7C0E37C476FB508C170F0AE6017C16A1C6 could help you to find out
 LOGJAM (CVE-2015-4000), experimental      not vulnerable (OK): no DH EXPORT ciphers, no DH key detected with <= TLS 1.2
 BEAST (CVE-2011-3389)                     not vulnerable (OK), no SSL3 or TLS1
 LUCKY13 (CVE-2013-0169), experimental     not vulnerable (OK)
 Winshock (CVE-2014-6321), experimental    not vulnerable (OK)
 RC4 (CVE-2013-2566, CVE-2015-2808)        no RC4 ciphers detected (OK)


 Running client simulations (HTTP) via sockets

 Browser                      Protocol  Cipher Suite Name (OpenSSL)       Forward Secrecy
------------------------------------------------------------------------------------------------
 Android 4.4.2                TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       256 bit ECDH (P-256)
 Android 5.0.0                TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       256 bit ECDH (P-256)
 Android 6.0                  TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       256 bit ECDH (P-256)
 Android 7.0 (native)         TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       256 bit ECDH (P-256)
 Android 8.1 (native)         TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       253 bit ECDH (X25519)
 Android 9.0 (native)         TLSv1.3   TLS_AES_256_GCM_SHA384            253 bit ECDH (X25519)
 Android 10.0 (native)        TLSv1.3   TLS_AES_256_GCM_SHA384            253 bit ECDH (X25519)
 Chrome 74 (Win 10)           TLSv1.3   TLS_AES_256_GCM_SHA384            253 bit ECDH (X25519)
 Chrome 79 (Win 10)           TLSv1.3   TLS_AES_256_GCM_SHA384            253 bit ECDH (X25519)
 Firefox 66 (Win 8.1/10)      TLSv1.3   TLS_AES_256_GCM_SHA384            253 bit ECDH (X25519)
 Firefox 71 (Win 10)          TLSv1.3   TLS_AES_256_GCM_SHA384            253 bit ECDH (X25519)
 IE 6 XP                      No connection
 IE 8 Win 7                   No connection
 IE 8 XP                      No connection
 IE 11 Win 7                  No connection
 IE 11 Win 8.1                No connection
 IE 11 Win Phone 8.1          No connection
 IE 11 Win 10                 TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       256 bit ECDH (P-256)
 Edge 15 Win 10               TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       253 bit ECDH (X25519)
 Edge 17 (Win 10)             TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       253 bit ECDH (X25519)
 Opera 66 (Win 10)            TLSv1.3   TLS_AES_256_GCM_SHA384            253 bit ECDH (X25519)
 Safari 9 iOS 9               TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       256 bit ECDH (P-256)
 Safari 9 OS X 10.11          TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       256 bit ECDH (P-256)
 Safari 10 OS X 10.12         TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       256 bit ECDH (P-256)
 Safari 12.1 (iOS 12.2)       TLSv1.3   TLS_CHACHA20_POLY1305_SHA256      253 bit ECDH (X25519)
 Safari 13.0 (macOS 10.14.6)  TLSv1.3   TLS_CHACHA20_POLY1305_SHA256      253 bit ECDH (X25519)
 Apple ATS 9 iOS 9            TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       256 bit ECDH (P-256)
 Java 6u45                    No connection
 Java 7u25                    No connection
 Java 8u161                   TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       256 bit ECDH (P-256)
 Java 11.0.2 (OpenJDK)        TLSv1.3   TLS_AES_256_GCM_SHA384            256 bit ECDH (P-256)
 Java 12.0.1 (OpenJDK)        TLSv1.3   TLS_AES_256_GCM_SHA384            256 bit ECDH (P-256)
 OpenSSL 1.0.2e               TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       256 bit ECDH (P-256)
 OpenSSL 1.1.0l (Debian)      TLSv1.2   ECDHE-RSA-AES128-GCM-SHA256       253 bit ECDH (X25519)
 OpenSSL 1.1.1d (Debian)      TLSv1.3   TLS_AES_256_GCM_SHA384            253 bit ECDH (X25519)
 Thunderbird (68.3)           TLSv1.3   TLS_AES_256_GCM_SHA384            253 bit ECDH (X25519)


 Rating (experimental)

 Rating specs (not complete)  SSL Labs's 'SSL Server Rating Guide' (version 2009q from 2020-01-30)
 Specification documentation  https://github.com/ssllabs/research/wiki/SSL-Server-Rating-Guide
 Protocol Support (weighted)  0 (0)
 Key Exchange     (weighted)  0 (0)
 Cipher Strength  (weighted)  0 (0)
 Final Score                  0
 Overall Grade                T
 Grade cap reasons            Grade capped to T. Issues with the chain of trust (self signed CA in chain)
                              Grade capped to A. HSTS is not offered

 Done 2020-12-30 03:48:04 [  97s] -->> 198.18.1.202:443 (frontend-project1.apps.ocp01.example.com) <<--
```

Test [result](manifests/test-ssl-2.log) of [Google](https://www.google.com) 



## Access Log

Router's access log can be enabled to syslog or container logging by add spec.logging.acess.destination.type to IngressController in openshift-ingress-operator namespace

Following set default IngressController with access log in container.

```bash
  oc patch IngressController default -n openshift-ingress-operator -p '{"spec":{"logging":{"access":{"destination":{"type":"Container"}}}}}' --type=merge
  oc patch IngressController default -n openshift-ingress-operator -p '{"spec":{"logging":{"access":{"httpLogFormat":"%ci:%cp [%t] %ft %b/%s %B %bq %HM %HU %HV"}}}}' --type=merge
  watch oc get pods -n openshift-ingress
```

Check output that router pod contains 2 containers

```bash
NAME                              READY   STATUS        RESTARTS   AGE
router-default-64bb598c79-78lks   1/1     Running       0          18m
router-default-64bb598c79-w4mgl   1/1     Terminating   0          18m
router-default-66d57c45c8-2lsvq   2/2     Running       0          15s
router-default-66d57c45c8-hh4n5   2/2     Running       0          15s
```
### Verify Access Log
#### Sidecar 

```bash
ROUTER_POD=$(oc get pods -n openshift-ingress -o 'custom-columns=Name:.metadata.name' --no-headers | head -n 1)
oc log -f $ROUTER_POD -n openshift-ingress -c logs
```

Sample out acesslog

```log
.226:51394 [09/Mar/2022:02:49:20.812] fe_sni~ be_edge_http:project1:frontend/pod:frontend-v2-868959894b-mlld2:frontend:http:10.128.2.47:8080 532 0 GET / HTTP/1.1
```

#### Internal ElasticSearch
