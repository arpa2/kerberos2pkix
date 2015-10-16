#
# ticket2cert & cert2ticket
#
# Preparation: Unpack librk5 source code, cd libkrb5/src, ./configure but not make.
#
# Edit src/lib/krb5/libkrb5.exports and add the following labels:
#    asn1buf_create
#    asn1buf_destroy
#    asn1buf_insert_bytestring
#    asn12krb5_buf
#    asn1_encode_integer
#    asn1_encode_oid
#    asn1_encode_generaltime
#    asn1_encode_bitstring
#    asn1_make_tag
#    asn1_make_sequence
#
# Now make.  We will include libraries directly, to gain the exported ASN.1 fun.
#
# Pieces of the code are used in these utilities.
#

KRBSRC=/usr/local/src/krb5-1.10.1+dfsg

INCDIR1=$(KRBSRC)/src/lib/krb5/asn.1 
INCDIR2=$(KRBSRC)/src/include/ 
KRBLIBS=-Xlinker -rpath=$(KRBSRC)/src/lib $(KRBSRC)/src/lib/libkrb5.so $(KRBSRC)/src/lib/libk5crypto.so $(KRBSRC)/src/lib/libcom_err.so
# LIBDIR1=$(KRBSRC)/src/lib/krb5/krb
# LIBDIR2=$(KRBSRC)/src/lib/krb5/asn.1
# KRBLIBS=-lkrb5 $(LIBDIR2)/asn1_make.c $(LIBDIR2)/asn1_encode.c $(LIBDIR2)/asn1_make.c

all: ticket2cert

ticket2cert: ticket2cert.c
	gcc -I $(INCDIR1) -I $(INCDIR2) -ggdb3 -o $@ $< $(KRBLIBS) -lcrypto
