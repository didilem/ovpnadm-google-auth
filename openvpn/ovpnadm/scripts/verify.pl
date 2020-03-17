#!/usr/bin/perl

#    © 2015 / Lembke Computer Consulting GmbH /  http://www.lcc.ch
#
#    This file is part of OpenVPN Admin.
#
#    OpenVPN Admin is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation GPL version 3.
#
#    OpenVPN Admin is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with OpenVPN Admin if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

use strict;

BEGIN {
	use vars qw($VERSION $LIFETIME $DEBUG $MTIME $CIPHER);
	# Version of this engine
	$VERSION = '1.0';
	$DEBUG = 1;
	$MTIME = undef;
	push @INC, '/etc/openvpn/ovpnadm/lib';
}

use DBI;
use OVPNADM::config;

my $dbh = DBI->connect(
    "dbi:mysql:dbname=$DBH->{'db'};host=$DBH->{'host'}",
    "$DBH->{'user'}", "$DBH->{'pass'}",
     {RaiseError => 0, PrintError => 1, mysql_enable_utf8 => 1}
 ) or die "Connect to database failed.";

my @args = @ARGV;

my %cns = (
	'info@yourcompany.com',1,
	# Users
	'lembke@lcc.ch',0,
);

my $email = '';
my $cn = '';

$args[1] =~ m/CN=([^\,]+)\,/ && ($cn = $1);
$args[1] =~ m,emailAddress=([a-zA-Z0-9\_@\.\-]+/?), && ($email = $1);


# Special validated accounts
exit 0 if $cns{$email};

my $sth = $dbh->prepare("SELECT clients_id,active FROM clients WHERE email = ? AND cname = ?");
$sth->execute($email,$cn);

if ($sth->rows != 1) { # Something is wrong, either subject does not match or to many matches
	exit 1;
}

my @rec = $sth->fetchrow_array;

# log attempt
$sth = $dbh->prepare("INSERT INTO clientlogin VALUES (?,now(),?)");
$sth->execute($rec[0],$rec[1]);

if ($rec[1] !~ /y/i) { # Certificate is not active
	exit 1;
}

$sth = $dbh->prepare("SELECT network,mask,name FROM networks LEFT JOIN grp2network ON " .
	"netid = networks_id LEFT JOIN clients2groups ON clients2groups.grpid = grp2network.grpid " .
	"WHERE cid = ? GROUP BY networks_id");
$sth->execute($rec[0]);

if (!$sth->rows) { # No Networks defined
	exit 1;
}

open(CCD, ">/etc/openvpn/ovpnadm/ccd/$cn") || (exit 0); # If we can open it there might be a protected ccd file
while (my @rec = $sth->fetchrow_array) {
	print CCD "push \"route $rec[0] $rec[1]\"\n";
}

print CCD <<EOF;
push "dhcp-option DNS 172.18.1.1"
EOF
#push "dhcp-option DOMAIN-SEARCH lxd"

close(CCD);

# valid cert
exit 0;
