---
layout: post-math
title:  "Reading domain name from X509 in sites"
description: "Reading the domain name from sites with X509 certificates"
date:   2020-09-25 21:53:48
categories: development
tags: [java, x509]
comments: true
---

* TOC
{:toc}

In some specific setups you might need to retrieve the Fully Qualified Domain Name (FQDN) from a given site. In other words, this is usually the DNS entry to which a given HTTPS-exposed service (running in a given IP) is bound. For instance, you may need to obtain the FQDN from your local IP, so that you can return absolute endpoints to a third-party application that will load some resource externally.

<!--more-->

In this Java class, this is done in a simple, minimal way. The code comes from multiple sources -referenced inline- and is slightly modified to return a list of FQDN names.

It will first establish an SSL connection (using [this source](https://www.xinotes.net/notes/note/1088/)) so it can load the chain of certificates. Typically, the first one will be the server one, and the subsequent ones are CAs which signed the "next" one in the chain (or the one "above", if we assume that the "mother CA" is at the root).

After loading the chain of X509 certificates, as described in [this source](https://stackoverflow.com/a/41441860/2186237), it attempts to retrieve first the FQDN value from the DNS name. In a decoded X509 certificate, this would be located under "*X509v3 extensions*" and then inside "*X509v3 Subject Alternative Name*". If nothing is there, it will just default to the value inside the "*Common Name*" field of the issuer (as [described here](https://stackoverflow.com/a/5527171/2186237)).

### The DNS entry in the X509 certificate

First of all, it is useful to check the decoded X509 certificate directly from the site we would like to read from. Using this command and filling in the expected IP in the "ipv4" variable, we can read all the fields of the certificate:

```bash
ipv4="a.b.c.d"; echo | openssl s_client -showcerts -servername ${ipv4} \
    -connect ${ipv4}:443 2>/dev/null | openssl x509 -inform pem -noout \
    -text
```

Using the 8.8.8.8 (Google) and 1.1.1.1 (Cloudflare) IPv4, we can observe the fields. Only the relevant fields will be shown here.

```bash
# Google
ipv4="8.8.8.8"; echo | openssl s_client -showcerts -servername ${ipv4} \
    -connect ${ipv4}:443 2>/dev/null | openssl x509 -inform pem -noout \
    -text

Certificate:
    Data:
        ...
        Issuer: C = US, O = Google Trust Services, CN = GTS CA 1O1
        ...
        Subject: C = US, ST = California, L = Mountain View,
        O = Google LLC, CN = dns.google
        ...
        X509v3 extensions:
            ...
            X509v3 Subject Alternative Name:
                DNS:dns.google, DNS:*.dns.google.com, DNS:8888.google,
                DNS:dns.google.com, DNS:dns64.dns.google,
                IP Address:2001:4860:4860:0:0:0:0:64,
                IP Address:2001:4860:4860:0:0:0:0:6464,
                IP Address:2001:4860:4860:0:0:0:0:8844,
                IP Address:2001:4860:4860:0:0:0:0:8888,
                IP Address:8.8.4.4, IP Address:8.8.8.8
            ...
         ...

# Cloudflare
ipv4="1.1.1.1"; echo | openssl s_client -showcerts -servername ${ipv4} \
    -connect ${ipv4}:443 2>/dev/null | openssl x509 -inform pem -noout \
    -text

Certificate:
    Data:
        ...
        Issuer: C = US, O = DigiCert Inc,
        CN = DigiCert ECC Secure Server CA
        ...
        Subject: C = US, ST = California, L = San Francisco,
        O = "Cloudflare, Inc.", CN = cloudflare-dns.com
        ...
        X509v3 extensions:
            ...
            X509v3 Subject Alternative Name: 
                DNS:cloudflare-dns.com, DNS:*.cloudflare-dns.com,
                DNS:one.one.one.one,
                IP Address:1.1.1.1, IP Address:1.0.0.1,
                IP Address:162.159.132.53,
                IP Address:2606:4700:4700:0:0:0:0:1111,
                IP Address:2606:4700:4700:0:0:0:0:1001,
                IP Address:2606:4700:4700:0:0:0:0:64,
                IP Address:2606:4700:4700:0:0:0:0:6400,
                IP Address:162.159.36.1, IP Address:162.159.46.1
            ...
    ...
```

Given this, it seems that the "*X509v3 extensions:*" > "*X509v3 Subject Alternative Name*" field is the one providing better detail. Some DNS entries provide values that we may not be that interested in, so the assumption here made is that the a DNS entry with a wildcard (thus, allowing subdomains) is the most adequate for our needs. This does not need to hold true, of course; but this is tailored to a specific environment.

In case the subject alternative name is not enough (unlikely, though), the "*Subject*" > "*CN*" can be retrieved (note that this is different to the issuer one).

### Retrieve the FQDN value

Given the findings above obtained, the following code can be implemented.

```java
import org.bouncycastle.asn1.x500.RDN;
import org.bouncycastle.asn1.x500.X500Name;
import org.bouncycastle.asn1.x500.style.BCStyle;
import org.bouncycastle.asn1.x500.style.IETFUtils;
import org.bouncycastle.cert.jcajce.JcaX509CertificateHolder;

import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSession;
import javax.net.ssl.SSLSocket;
import javax.net.ssl.SSLSocketFactory;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.net.InetAddress;
import java.net.NetworkInterface;
import java.security.KeyManagementException;
import java.security.NoSuchAlgorithmException;
import java.security.cert.Certificate;
import java.security.cert.CertificateException;
import java.security.cert.CertificateFactory;
import java.security.cert.CertificateParsingException;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Collections;
import java.util.Enumeration;
import java.util.List;

public class CertificateUtils {

    private static final Logger logger = new Logger(CertificateUtils.class);

    // Source from https://www.xinotes.net/notes/note/1088/
    // Create custom trust manager to ignore trust paths
    static TrustManager trm = new X509TrustManager() {
        public X509Certificate[] getAcceptedIssuers() {
            return null;
        }

        public void checkClientTrusted(X509Certificate[] certs, String authType) {
        }

        public void checkServerTrusted(X509Certificate[] certs, String authType) {
        }
    };

    // Get chain of certificates (source from https://www.xinotes.net/notes/note/1088/)
    public static Certificate[] getCertificateChain(String host, int port) throws
            NoSuchAlgorithmException, IOException, KeyManagementException {
        SSLContext sc = SSLContext.getInstance("SSL");
        sc.init(null, new TrustManager[]{trm}, null);
        SSLSocketFactory factory = sc.getSocketFactory();
        SSLSocket socket = (SSLSocket) factory.createSocket(host, port);
        socket.startHandshake();
        SSLSession session = socket.getSession();
        Certificate[] serverCerts = session.getPeerCertificates();
        socket.close();
        return serverCerts;
    }

    public static Certificate[] getCertificateChain(String host) throws
            NoSuchAlgorithmException, IOException, KeyManagementException {
        // By default an SSL connection will be exposed in port 443
        return getCertificateChain(host, 443);
    }

    public static ArrayList<String> getCNsFromChain(Certificate[] chain) throws CertificateException {
        ArrayList<String> chainCNs = new ArrayList<>();
        // The first certificate will be the one for the exposed service. Going up in the chain reaches the top CAs
        for (Certificate cert : chain) {
            // Read X509 certificate (source from https://stackoverflow.com/a/41441860/2186237)
            ByteArrayInputStream inputStream = new ByteArrayInputStream(cert.getEncoded());
            CertificateFactory certFactory = CertificateFactory.getInstance("X.509");
            X509Certificate dec = (X509Certificate) certFactory.generateCertificate(inputStream);
            JcaX509CertificateHolder decJCA = new JcaX509CertificateHolder(dec);
            // Attempt 1: obtain DNS name (X509v3 extensions > X509v3 Subject Alternative Name)
            try {
                Collection<List<?>> altNames = dec.getSubjectAlternativeNames();
                if (altNames == null) {
                    altNames = Collections.emptyList();
                }
                for (List<?> item : altNames) {
                    // Remove wildcards from CN
                    if (item.size() >= 2) {
                        chainCNs.add(item.get(1).toString());
                    }
                }
            } catch (CertificateParsingException e) {
                logger.error("Error parsing SubjectAltName in certificate: " + dec + "\r\nerror:" + e.getLocalizedMessage(), e);
            }
            // Attempt 2: obtain subject CN (source from https://stackoverflow.com/a/5527171/2186237)
            if (chainCNs.isEmpty()) {
                X500Name x500name = decJCA.getSubject();
                RDN cn = x500name.getRDNs(BCStyle.CN)[0];
                String commonName = IETFUtils.valueToString(cn.getFirst().getValue());
                chainCNs.add(commonName);
            }

            for (int i = 0; i < chainCNs.size(); i++) {
                // Remove wildcards from CN
                chainCNs.set(i, chainCNs.get(i).replace("*.", ""));
            }
        }

        return chainCNs;
    }
}
```

### Test it

A very simple test can be tried as follows. This will open SSL connections towards both IPs mentioned in the first section (for Google and Cloudflare) and verify that their respective FQDN corresponds to the expected alternative name from the X509 certificate.

```java
import org.junit.Test;

import java.security.cert.Certificate;
import java.util.ArrayList;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

public class CertificateUtilsTest {

    private void shouldGetCN(String expectedCN, String hostIP) throws Exception {
        Certificate[] chainCerts = CertificateUtils.getCertificateChain(hostIP);
        ArrayList<String> chainCNs = CertificateUtils.getCNsFromChain(chainCerts);
        assertTrue(chainCNs.size() >= 1);
        assertEquals(expectedCN, chainCNs.get(0));
    }

    @Test
    public void shouldGetGoogleCN() throws Exception {
        shouldGetCN("dns.google", "8.8.8.8");
    }

    @Test
    public void shouldGetCloudflareCN() throws Exception {
        shouldGetCN("cloudflare-dns.com", "1.1.1.1");
    }
}
```
