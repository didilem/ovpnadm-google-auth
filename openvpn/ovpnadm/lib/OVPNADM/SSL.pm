package OVPNADM::SSL;

#    © 2015 / Lembke Computer Consulting GmbH /  http://www.lcc.ch
#
#    This file is part of OVPNADM.
#
#    OVPNADM is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation GPL version 3.
#
#    OVPNADM is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with OVPNADM; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#

use strict;

BEGIN {
	use vars qw($VERSION $DEBUG);
	# Version of this engine
	$VERSION = '1.0';
	$DEBUG = 1;
}

my %para = (
	shell => '/usr/bin/openssl',
	tmpDir => '/tmp',
	baseDir => '/etc/openvpn/ovpnadm/lib/openssl',
	cnf => 'openssl.cnf',
	cacert => 'certs/ca.cert.pem',
	crl => 'crl.pem',
	crltmp => 'crltmp.pem',
);

sub new {
	my $that = shift;
	my $class = ref($that) || $that;
	my $self = {};
	%{$self->{PARA}} = %para;
	@{$self->{ERRORS}} = ();
	bless ($self,$class);
	return $self;
}

sub sign_cert {
	my $self = shift;
	my $req = shift;

	my $ssl = "$para{'shell'} ca -days 7300 -batch " . 
			"-in '$para{'baseDir'}/test-certs/$req->{EMAIL}.req.pem' " .
			"-out '$para{'baseDir'}/test-certs/$req->{EMAIL}.cert.pem' " .
			"-config '$para{'baseDir'}/$para{'cnf'}' -notext";

	system("/bin/bash -c \"$ssl\" >/dev/null 2>&1");
		
	if ($?) {
		push(@{$self->{ERRORS}}, $?);
		return 0;
	}
}

sub revokeCert {
	my $self = shift;
	my $serial = shift;

	unless (-e "$para{'baseDir'}/certs/$serial.cert.pem") {
		return 0;
	}

	my $ssl = "$para{'shell'} ca -revoke $para{'baseDir'}/certs/$serial.cert.pem " .
		"-config '$para{'baseDir'}/$para{'cnf'}'";

	system("/bin/bash -c \"$ssl\" ");
		
	if ($?) {
		push(@{$self->{ERRORS}}, $?);
		return $?;
	}

	my $ssl = "$para{'shell'} ca -gencrl -crldays 720 -out $para{'baseDir'}/$para{'crltmp'} " .
		"-config '$para{'baseDir'}/$para{'cnf'}'";

	system("/bin/bash -c \"$ssl\"");
		
	if ($?) {
		push(@{$self->{ERRORS}}, $?);
		return $?;
	}

	my $ssl = "cat $para{'baseDir'}/$para{'cacert'} $para{'baseDir'}/$para{'crltmp'} > " .
		"$para{'baseDir'}/$para{'crl'}";

	system("/bin/bash -c \"$ssl\" >/dev/null 2>&1");
		
	if ($?) {
		push(@{$self->{ERRORS}}, $?);
		return $?;
	}
	return 1;
}

sub certSubject {
	my $self = shift;
	my ($k,$v) = '';
	my @entities = split(',', $self->{CERT}{SUBJECT});
	foreach(@entities) {
		s/^\s+//;
		if (/^CN/) {
			foreach my $cn (split('/')) {
				$cn =~ /^([^=]+)\=(.*)/ && ($self->{CERT}{$1} = $2);
			}
		} else {
			($k,$v) = split('=');
			$self->{CERT}{$k} = $v;
		}
	}
	return $self->{CERT}{SUBJECT};
}

sub certStartEnd {
	my $self = shift;
	return [$self->{CERT}{NOTBEFORE},$self->{CERT}{NOTAFTER}];
}

sub certSerial {
	my $self = shift;
	return $self->{CERT}{SERIAL};
}

sub certText {
	my $self = shift;
	return $self->{CERT}{TEXT};
}

sub certDetails {
	my $self = shift;
	return $self->{CERT};
}

sub getKey {
	my $self = shift;
	return $self->{KEY};
}

sub getCA {
	my $self = shift;
	open(CERT, "$para{'baseDir'}/$para{'cacert'}") ;
	while(<CERT>){
		$self->{CA} .= $_;
	}
	close(CERT);
	return $self->{CA};
}

sub getClientCertsEnc {
	my $self = shift;
	my $serial = shift;
	my $key = shift;
	# Get the client Cert 
	open(CERT, "$para{'shell'} x509 -in '$para{'baseDir'}/certs/$serial.cert.pem'|");
	while(<CERT>){
		$self->{CERT}{CERT} .= $_;
	}
	close(CERT);
	open(KEY, "$para{'baseDir'}/certs/$serial.key.pem") || die();
	while(<KEY>){
		$self->{CERT}{KEY} .= $_;
	}
	close(KEY);
	open(CA, "$para{'baseDir'}/$para{'cacert'}") ;
	while(<CA>){
		$self->{CERT}{CA} .= $_;
	}
	close(CA);
	return $self->{CERT};
}

sub getClientCerts {
	my $self = shift;
	my $cert = shift;
	my $key = shift;
	# Get the client Cert 
	open(CERT, "$para{'shell'} x509 -text -in '$cert'|") ;
	while(<CERT>){
		$self->{CERT}{TEXT} .= $_;
		/\s+Subject:\s+(.*)$/ && ($self->{CERT}{SUBJECT} = $1);
		/\s+Not\s+Before:\s+(.*)$/ && ($self->{CERT}{NOTBEFORE} = $1);
		/\s+Not\s+After\s*:\s+(.*)$/ && ($self->{CERT}{NOTAFTER} = $1);
		/^\s+Serial\s+Number:\s+.*\((.*)\)$/ && ($self->{CERT}{SERIAL} = $1);
	}
	close(CERT);
	open(CERT, "$key") ;
	while(<CERT>){
		$self->{KEY} .= $_;
	}
	close(CERT);
	$self->{CERT}{KEY} = $self->{KEY};
	open(CERT, "$para{'baseDir'}/$para{'cacert'}") ;
	while(<CERT>){
		$self->{CA} .= $_;
	}
	close(CERT);
	$self->certSubject();
	return $self->{CERT};
}

sub create_client_cert {
	my $self = shift;
	my $req = shift;

	my $ssl = "$para{'shell'} req " .
			($req->{NODE} ? '-nodes ':"-passout pass:'$req->{PASS}' ") .
			'-rand /proc/interrupts:/proc/net/rt_cache ' .
			'-newkey rsa:2048 -sha256 ' .
			"-keyout '$para{'baseDir'}/test-certs/$req->{EMAIL}.key.pem' " .
			"-out '$para{'baseDir'}/test-certs/$req->{EMAIL}.req.pem' " .
			"-config '$para{'baseDir'}/$para{'cnf'}'";

	my $pid = open(OPENSSL, "| $ssl 2>&1") || die;
	
	print OPENSSL "$req->{COUNTRY}\n";
	print OPENSSL "$req->{STATE}\n";
	print OPENSSL "$req->{LOCATION}\n";
	print OPENSSL "$req->{O}\n";
	print OPENSSL "$req->{OU}\n";
	print OPENSSL "$req->{CN}\n";
	print OPENSSL "$req->{EMAIL}\n";
	close (OPENSSL);
	if ($?) {
		push(@{$self->{ERRORS}}, $?);
		return;
	}
	$self->sign_cert($req);
	$self->{tmpcert} = 
		["$para{'baseDir'}/test-certs/$req->{EMAIL}.cert.pem",
		"$para{'baseDir'}/test-certs/$req->{EMAIL}.key.pem",
		"$para{'baseDir'}/test-certs/$req->{EMAIL}.req.pem"];
	return;
}

sub getCertDetails {
	my $self = shift;
	my $cert = shift;
}

sub verifyCerts {
	my $self = shift;
	my $cert = shift;
	my $key = shift;
	my $pass = shift;
	my $mcert = '';
	my $mkey = '';

	open (CERT, "$para{'shell'} x509 -noout -modulus -in $cert |") || die;
	while(<CERT>) {
		$mcert = $_;
	} 
	close(CERT);

	if ($?) {
		return 'error_cert';
	}

	if ($pass) { # test if the cert has passphrase with an empty pass
 		open (KEY, "$para{'shell'} rsa -noout -modulus -passin pass: -in $key |") || die;
		while(<KEY>) {
			$mkey = $_;
		} 
		close(KEY);

		unless ($?) { # the key already carries a passphrase
			# add the provided passphrase to the key
	    	open (KEY, "$para{'shell'} rsa -in $key -passin pass: -passout pass:'$pass' -des3 -out $key|") || die;
	    	while(<KEY>) {
				$mkey = $_;
			} 
			close(KEY);

			if ($?) {
				return 'error_key_adding_pass';
			}
		}
	}
	open (KEY, "$para{'shell'} rsa -noout -modulus -passin pass:'$pass' -in $key |") || die;
	while(<KEY>) {
		$mkey = $_;
	} 
	close(KEY);

	if ($?) {
		return 'error_key';
	}

	unless ($mcert eq $mkey) { #cert does not belong to key
		return 'error_cert_key';
	}

	open (KEY, "$para{'shell'} verify -CAfile  '$para{'baseDir'}/$para{'cacert'}' $cert |") || die;
	while(<KEY>) {
		$mkey = $_;
	}
	close(KEY);
	if ($?) {
		return 'error_cert_not_ours';
	}

	open (KEY, "$para{'shell'} verify -CAfile '$para{'baseDir'}/$para{'crl'}' -crl_check $cert |") || die;
	while(<KEY>) {
		$mkey = $_;
	}
	close(KEY);
	if ($?) {
		return 'error_cert_revoked';
	}    
	
	return;
}
1;
