#!/usr/bin/perl
#
# mySociety/AuthToken.pm:
# General utilities for tokens mapped to hashes.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# WWW: http://www.mysociety.org/

package mySociety::AuthToken;

use strict;

use Digest::SHA qw(sha1_hex);
use IO::String;
use MIME::Base64 qw(encode_base64);

use mySociety::DBHandle qw(dbh);
use mySociety::Random qw(random_bytes);
use mySociety::BaseN;

use RABX;

=item ab64_encode DATA

Return a base57 encoding of DATA (like base64 but not using . or / or
some easy-to-confuse letters, O 0 I 1 l.

=cut
sub ab64_encode ($) {
    my $t = mySociety::BaseN::encodefast(57, $_[0]);
    $t =~ tr#O01Il#56789#;
    return $t;
}

=item random_token

Return a new random token.

=cut
sub random_token () {
    return ab64_encode(random_bytes(12, 1));
}

=item store SCOPE DATA

Return a randomly generated token suitable for use in URLs. SCOPE is the
associated scope and DATA is a reference to information to be serialised in the
database; typically this should be a reference to hash.

=cut
sub store ($$) {
    my ($scope, $data) = @_;
    my $token = random_token();
    my $ser = '';
    my $h = new IO::String($ser);
    RABX::wire_wr($data, $h);
    dbh()->do('
            insert into token (scope, token, data, created)
            values (?, ?, ?, ms_current_timestamp())', {},
            $scope, $token, $ser);
    return $token;
}

=item retrieve SCOPE TOKEN

Given a TOKEN returned by store for the given SCOPE, return the data associated
with it, or undef if there is none.

=cut
sub retrieve ($$) {
    my ($scope, $token) = @_;
    my $ser = dbh()->selectrow_array('
                select data from token
                where scope = ? and token = ?', {},
                $scope, $token);
    return undef unless(defined($ser));
    my $h = new IO::String($ser);
    return RABX::wire_rd($h);
}

=item destroy SCOPE TOKEN

Delete any data associated with TOKEN in the given SCOPE.

=cut
sub destroy ($$) {
    my ($scope, $token) = @_;
    dbh()->do('delete from token where scope = ? and token = ?', {},
            $scope, $token);
}

# sign_with_shared_secret ITEM SECRET
# Signs a string ITEM, using a shared secret string SECRET.  Returns the
# SIGNATURE. Pass the ITEM and SIGNATURE into verify_with_shared_secret
# to check it.
sub sign_with_shared_secret ($$) {
    my ($item, $secret) = @_;
    my $salt = unpack("H*", random_bytes(8, 1));
    my $sha = sha1_hex("$salt-$secret-$item");
    return "$sha-$salt";
}

# verify_with_shared_secret ITEM SECRET SIGNATURE
# Verifies that the ITEM has been correctly signed with SIGNATURE.  The signer
# must also have had SECRET and will have called sign_with_shared_secret
# to make the SIGNATURE.
sub verify_with_shared_secret ($$$) {
    my ($item, $secret, $signature) = @_;
    return 0 unless $signature =~ /^([0-9a-f]+)-([0-9a-f]+)$/;
    my ($sha, $salt) = ($1, $2);
    return 1 if sha1_hex("$salt-$secret-$item") eq $sha;
    return 0;
}

1;
