#!/usr/bin/perl
# 
# Dress.pm:
# Look up postal addresses from Address-Point
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Dress.pm,v 1.1 2007-03-19 10:03:25 matthew Exp $

package mySociety::Dress;

use strict;
use mySociety::Config;

# Dress DB - need to make DBHandle DBHandles?
my $connstr = 'dbi:Pg:dbname=' . mySociety::Config::get('DRESS_DB_NAME') .';sslmode=allow';
$connstr .= ";host=" . mySociety::Config::get('DRESS_DB_HOST')
    if (mySociety::Config::get('DRESS_DB_HOST'));
$connstr .= ";port=" . mySociety::Config::get('DRESS_DB_PORT')
    if (mySociety::Config::get('DRESS_DB_PORT'));
my $dbh = DBI->connect($connstr,
    mySociety::Config::get('DRESS_DB_USER'),
    mySociety::Config::get('DRESS_DB_PASS'), {
        AutoCommit => 0,
        PrintError => 0,
        PrintWarn => 0,
        RaiseError => 0,
        pg_enable_utf8 => 1
    }
);

sub find_nearest($$) {
    my ($easting, $northing) = @_;
    my ($id, $distance) = $dbh->selectrow_array("select * from address_find_nearest(?,?)", {}, $easting, $northing);
    return '' unless $id;
    my ($address, $postcode) = $dbh->selectrow_array("select address,postcode from address where id=?", {}, $id);
    $address =~ s/\n/, /g;
    return sprintf("%s, %s (distance %.2fm)", $address, $postcode, $distance);
}

1;
