#!/usr/bin/perl

#    © 2018 / Lembke Computer Consulting GmbH /  http://www.lcc.ch
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
BEGIN {
   use vars qw($VERSION $LIFETIME $DEBUG $MTIME $CIPHER);
   # Version of this engine
   $VERSION = '1.0';
   $DEBUG = 1;
   $MTIME = undef;
   push @INC, '/etc/openvpn/ovpnadm/lib';
}

use DBI;
use Authen::OATH;
use Convert::Base32;
use OVPNADM::config;
use Digest::MD5 qw(md5 md5_hex md5_base64);

my $dbh = DBI->connect(
    "dbi:mysql:dbname=$DBH->{'db'};host=$DBH->{'host'}",
    "$DBH->{'user'}", "$DBH->{'pass'}",
     {RaiseError => 0, PrintError => 1, mysql_enable_utf8 => 1}
 ) or die "Connect to database failed.";

my %cns = (
   'ovpnadm@yourdomain.com',1,
   # Users
   'lembke@lcc.ch',0,
);

my $email = $ENV{username};
my $given_token = $ENV{password};

# Special validated accounts
exit 0 if ($cns{$email} || $cns{$ENV{X509_0_emailAddress}}); # X509_0_emailAddress server as client

my $sth = $dbh->prepare("SELECT auth_secret,auth_token FROM clients WHERE email = ?");
$sth->execute($email);

if ($sth->rows != 1) { # Something is wrong, either subject does not match or to many matches
   exit 1;
}
my @rec = $sth->fetchrow_array;

debug("------------\nAuth token and stored token: $given_token:$rec[1]");

my $correct_token = make_token_6(
   Authen::OATH->new->totp(
      decode_base32( $rec[0] )
   )
);

if ($rec[1] ne 'NULL' && $given_token eq $rec[1]) {
	debug("User $email is authed by stored token");
	# the user is authed by the token
	update_token($given_token,$email,1);
	exit 0;
}


debug("$correct_token:$given_token");
debug("password: $ENV{password}");

$given_token = make_token_6($given_token);

if ($given_token eq $correct_token) {
   update_token($correct_token,$email);
   debug("user $email is allowed");
   exit 0;
close(TMP);
} else {
   debug("Nope!");
   exit 1;
close(TMP);
}

sub update_token {
	my $token = shift;
	my $email = shift;
	my $org = shift;
	debug("updating connection");
	my $tok = $org ? $token:($token . time);
	$sth = $dbh->prepare("update clients set auth_token = ? where email = ?");
	$sth->execute($tok,$email);
	open(CNF, ">>/etc/openvpn/ovpnadm/ccd/$ENV{X509_0_CN}");
	print CNF "push \"auth-token $tok\"\n";
	close(CNF);
}

sub make_token_6 {
   my $token = shift;
   while (length $token < 6) {
   $token = "0$token";
   }
   return $token;
}

sub debug {
	open(TMP, ">>/tmp/openvpn.dbg");
	my $msg = shift;
	print TMP "$msg\n";
	close(TMP);
}
