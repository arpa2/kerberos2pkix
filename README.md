Moulding Kerberos into PKIX
===========================

>   *A wild experiment. Can we use an X.509 certificate structure to represent a
>   Kerberos ticket? Yes we can, and it isn’t even such a stretch of
>   imagination.*

See [Basic Certificate
Fields](<https://tools.ietf.org/html/rfc5280#section-4.1>).

TBSCertificate
--------------

This structure captures the information that will be signed by an authority (or
ourselves).

-   version. Set to v3(2).

-   serialNumber. Counter to be set only to valid UInt32 values; this field may
    be used to distinguish versions of a ticket’s use within (much more than)
    the validity window. Advised use is a usec timestamp with roll-over; this
    recycles after \>71 minutes.

-   issuer. If hidden, use an empty SEQUENCE. Otherwise, set it to the client’s
    Realm.

-   validity. The “certificate” is meant for immediate consumption, so it is
    short-lived, shorter even than the ticket contained in it; set validity to a
    few-minute window around the current time, for instance
    \<now-00:02:00,now+00:03:00\>

-   subject. If hidden, use an empty SEQUENCE. Otherwise, set it to the client’s
    PrincipalName.  The information is available in the ticket for the intended
    recipient,

-   subjectPublicKeyInfo. Set the AlgorithmIdentifier to algorithm “kerberos”
    with no parameters, and fill the subjectPublicKey with the ticket.

-   issuerUniqueID. Do not use. (Really?)

-   subjectUniqueID. Do not use. (Really?)

-   extensions. As desired; Extended Key Usage may prove useful.

Note that this takes a leap of faith, by treating the Ticket as a “public key”.
We’re reading this, slightly far-sighted, to mean a key that can be publicly
shown. This is indeed the case, but of course it is only useful for its intended
recipient so publishing it is of limited use.

Another point worth noting is the validity. With a normal certificate, this is
in the range of years, but long-lived certificates tend to cause problems. In
exchanges that require a certificate, it can be very light-weight to generate an
X.509 certificate on the fly and sign it with Kerberos. The validity can be
subsequently short, for instance a five-minute window around te current time. As
is common with Kerberos, clocks are assumed to be synchronised.

Certificate
-----------

This is the TBSCertificate plus a signature. We sign it on the fly using plain
Kerberos structures.

-   TBSCertificate. Detailed above.

-   signatureAlgorithm. Set the algorithm to “kerberos”. Do not include
    parameters.

-   signature. Find the etype in the ticket, determine the hash algorithm and
    run it over the TBSCertificate. Then include that value in the checksum
    field of the Authenticator, and the serialNumber into seq-number. Encrypt
    the Authenticator and store it in the signature field.

AlgorithmIdentifier
-------------------

We’ll need one for saying “kerberos”, but that’s just an OID or two…

We probably need identifiers for signing, encrypting, and perhaps more.

Choose an OID root, split into applications, then use the etype?  (No, etype
follows from the ticket used.)

Not all places will require an OID, but when they do, we need to have them
ready.

**signatureAlgorithm.**  We have the following [experimental
OIDs](<http://oid.arpa2.org>):

-   1.3.6.1.4.1.44469.666.509.88.1.1.2.1.3.14.3.2.26 for a SHA1 hash

-   1.3.6.1.4.1.44469.666.509.88.1.1.2.2.16.840.1.101.3.4.2.4 for a SHA-224 hash

-   1.3.6.1.4.1.44469.666.509.88.1.1.2.2.16.840.1.101.3.4.2.1 for a SHA-256 hash

-   1.3.6.1.4.1.44469.666.509.88.1.1.2.2.16.840.1.101.3.4.2.2 for a SHA-384 hash

-   1.3.6.1.4.1.44469.666.509.88.1.1.2.2.16.840.1.101.3.4.2.3 for a SHA-512 hash

The current checksum types for Kerberos have only got SHA1 listed; this is because
we're using the field in another manner; we'll be using SHA1 in the demo code.

Signing
-------

This is a similar operation to the certificate’s self-signature. There is no
seq-number field, that’s the only difference.  Is it better to also drop the
seq-number?  There is no chance of unnoticed replay when it is contained in the
hashed data.  That also gives more freedom for allocation of serialNumber
values.

Encryption
----------

This is the usual “wrap” operation of Kerberos.

Certificate Hierarchy
---------------------

A client could release a TGT signed with its own Ticket.  The TGT is not
directly usable for the recipient, except that it might serve for
`ENC-TKT-IN-SKEY`, but then we would like to know that it is indeed meant for
the intended recipient.

It might be interesting to have limited paths, for instance TGT-signed paths
between client and service.  Or trust delegation paths.  This might require new
additions to sign for the entire chain, rather than for the end unit alone.
This way, it can confirm that it agrees to the foregoing parts, even when these
are unreadable to others.

To this end, the hash might cover the entire chain instead of a single
certificate, or it might incorporate fingerprints for the trust chain’s
elements.

Note that this might also be useful for trust delegation, similar to what
S4U2Proxy uses.  That application however, might also require the hierarchy to
be a flattened version of what is in reality a partially ordered form.

Applications
------------

We can use this to release a ticket into TLS, as a client, by packing it into an
X.509 structure. The “kerberos” signature algorithm must be recognised of
course, and taken into account by the TLS stack, but since the ticket in its
X.509 form fits in the ClientCertificate and it can sign the ClientVerify there
should be no real problem, beyond implementing the algorithms by going through
Kerberos, and getting hold of the server’s ticket.

Further ideas
-------------

-   Perhaps allow expansion with a TGT; this is unusable to the client because
    it lacks the session key, but it can use it with `ENC-TKT-IN-SKEY` to permit
    sending information; this special case requires finding a user’s session
    key.

-   We may consider including more material, for instance in support of
    S4UProxy.  This would add a constraint to the TGT (namely, that it is
    `FORWARDED`) and it would need the corresponding session key.  For this
    purpose, we may use the .1.22 type, introducing the `[APPLICATION 22]` tag
    or KRB_CRED as a public key descriptor.  It holds a `SEQUENCE OF Ticket`,
    and could therefore provide a FORWARDED TGT in addition to a normal service
    ticket.  There also is an encrypted portion that has a place for a session key.

-   Since we’re supposed to know the ticket name of our server (realm from DNS,
    service host from URL, service name from application) do we really need to
    pass it on in all applications?  We might strip the Realm and PrincipalName
    in some certificates; for instance TLS should be able to reconstruct it from
    SNI and the realm name hint(s) that it yields internally.  We would be
    sending `EncTicketPart` `[APPLICATION 3]` instead of `Ticket` `[APPLICATION
    1]` and have a bit more privacy on the wire, and perhaps less opportunity
    for disagreement.

Structure for Public Key Info
-----------------------------

Just an experiment, in case we want to complicate matters (by supporting more
uses).

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
KerberosPublicKeyInfo ::= SEQUENCE {
        ap_ticket    [0] EXPLICIT Ticket,
        tgs_ticket   [1] EXPLICIT Ticket OPTIONAL,
        tgs_seskey   [2] EXPLICIT EncryptionKey OPTIONAL
        ...
}
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Implementation
--------------

-   The `Ticket` structure is available in C as `krb5_ticket`, with a
    `krb5_principal` for the `Realm` and `PrincipalName` and an encrypted part
    with, when available, a decrypted version as well.  The wire-format ticket
    structure is also part of `krb5_creds`.

-   The `EncryptedData` structure is available in C as `krb5_enc_data`, which
    lists an enctype, kvno and ciphertext blob.

-   The `Authenticator` structure is available in C as `krb5_authenticator`,
    with the various `AuthorizationData` elements in an array of `krb5_authdata`
    pointers.  It is not clear how long this array is (is it NULL-terminated?)
    and there does not appear to be support for nested structures.

-   See the [MIT kerberos5
    API](<http://web.mit.edu/kerberos/krb5-current/doc/appldev/refs/api/index.html>).

-   The Kerberos library contains `encode_krb5_ticket()` and
    `encode_krb5_authenticator()` for ASN.1 encoding of the structures.  There
    is also a function `asn1_make_sequence()` to encode a SEQUENCE.

-   Initial credentials are obtained with `krb5_init_creds_get_creds()`.  That
    means performing a login, so not really what we’re looking for.

-   The existing credentials cache is opened with `krb5_cc_default()` or, given
    the cache name, with `krb5_cc_resolve()`; the default principal of a cache
    is found with `krb5_cc_get_principal()` and the corresponding credential is
    taken out of the cache with `krb5_cc_retrieve_cred()` where the `mcreds`
    parameter would have the desired `client` name, the `server` is its initial
    TGT.  Alternatively, use the “manual” method, using
    `krb5_cc_start_seq_get()` / `krb5_cc_next_cred()` / `krb5_cc_end_seq_get()`
    with a `krb5_cc_cursor` to move through the credentials cache, one
    credential at a time.

-   Authenticators can be retrieved with `krb5_auth_con_getauthenticator()` but
    that assumes the existing application, not the one defined here.

-   Use `krb5_c_encrypt_length()` and `krb5_c_encrypt()` to actually encrypt the
    authenticator.  We should use key usage value 11 for now, but might allocate
    a special value for the purpose of X.509 certificate signatures.

-   Checksumming: For the sigalg OID without hash OID appended, use the checksum
    from the enctype; this may be insecure; for sigalg OIDs with trailing hash
    OID, use that hash algorithm.  Do not embellish the hash outcome with OIDs
    of any kind, just provide them as-is in the checksum field of the
    authenticator.  The checksum for an enctype can be looked up with
    `krb5_k_key_enctype()` —we will not permit overriding it as in
    mk\_ap\_req\_extended— and built with `krb5_k_make_checksum()`; key usage is
    (in AP\_REQ) is `KRB5_KEYUSAGE_AP_REQ_AUTH_CKSUM`.  Other checksums can be
    built using existing hash libraries; those would be more suited to X.509
    habits than to Kerberos habits.

Usable Instant Certificates?
----------------------------

-   Implement PKCS \#11 on top of this, generating the certificates locally and
    instantly

-   Somehow figure out what the targeted service for a certificate is, perhaps
    using a label
