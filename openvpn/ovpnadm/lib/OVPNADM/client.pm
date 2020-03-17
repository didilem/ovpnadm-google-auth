package OVPNADM::clients;

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
#

use strict;
use OVPNADM::config;
use OVPNADM::SSL;
use OVPNADM::network;
use Capture::Tiny qw/capture/;
use Convert::Base32;
use URI::Escape::XS qw/uri_escape uri_unescape/;

sub new {
   my $that = shift;
   my $class = ref($that) || $that;
   my $self = {};
   $self->{FIELDS} = shift;
   $self->{DBH} = shift;
   $self->{POST} = shift;
   bless ($self,$class);
   $self->{SSL} = OVPNADM::SSL->new();
   return $self;
}

sub createAuthentifcaterSecret {
	my $self = shift;
	my $len_secret_bytes = 50;
   open my $RNG, '<', '/dev/urandom'
      or die "Cannot open /dev/urandom for reading: $!";
   sysread $RNG, my $secret_bytes, $len_secret_bytes
      or die "Cannot read $len_secret_bytes from /dev/urandom: $!";
   close $RNG
      or die "Cannot close /dev/urandom: $!";


	my $secret_base32 = encode_base32( $secret_bytes );
	return $secret_base32;
}

sub createQRCode {
	my $self = shift;
	my $secret = shift;

	my $url   = sprintf("otpauth://totp/%s?secret=%s", $AUTHER->{'label'}, $secret);
	my $qr_url = sprintf("https://chart.googleapis.com/chart?chs=$AUTHER->{'qr-size'}x$AUTHER->{'qr-size'}" .
        "&chld=M|0&cht=qr&chl=%s", uri_escape($url));

	return $qr_url;
}

sub revokeConfig {
	my $self = shift;
	my $sth = $self->{DBH}->prepare("SELECT serial FROM clients WHERE clients_id = ?");
	$sth->execute($self->{FIELDS}->{manage});
	my $serial = $sth->fetchrow_array();
	my $test = $self->{SSL}->revokeCert($serial);
	if ($test) {
		my $sth = $self->{DBH}->prepare("DELETE from clients where clients_id = ?");
		$sth->execute($self->{FIELDS}->{manage});
		$sth = $self->{DBH}->prepare("DELETE from clients2groups where cid = ?");
		$sth->execute($self->{FIELDS}->{manage});

		return "Certificate revoked";
	}
	return "undefined error revoking certificate";
}

sub showConfirmDelete {
	my $self = shift;
	my $id = $self->{FIELDS}{manage};
	my $confirm = <<EOF;
<div id="confirmDelete_$id" class="confirmDelete" style="display:block">
<div class="button listEdit" onclick="revokeClientConfirmed('editNetwork_$id','$id');">delete client</div>
<div class="button listEdit" onclick="cancelRevoke('editNetwork_$id','netListContainer_$id');">cancel</div>
<div style=\"clear: left\"></div>
</div>
EOF
}

sub exportConfig {
	my $self = shift;
	my $sth = $self->{DBH}->prepare("SELECT serial,auth_secret FROM clients WHERE clients_id = ?");
	$sth->execute($self->{FIELDS}->{manage});
	my ($serial,$qrcode) = $sth->fetchrow_array();
	my $ca = $self->{SSL}->getClientCertsEnc($serial);
	my $qrcode = $self->createQRCode($qrcode);

	my $template = <<EOF;
<a href="$qrcode" target="_blank"><img src="$qrcode" /></a><br/>
<pre>
--- copy here ---
client
dev tun
proto udp
remote $SERVER->{'remote'} 1195
resolv-retry infinite
nobind
user nobody
group nogroup
persist-key
persist-tun
comp-lzo
verb 4
auth-user-pass
cipher AES-256-CBC
&lt;ca&gt;
$ca->{CA}&lt;/ca&gt;
&lt;cert&gt;
$ca->{CERT}&lt;/cert&gt;
&lt;key&gt;
$ca->{KEY}&lt;/key&gt;
--- copy end ---
</pre>
EOF
}

sub addClient {
	my $self = shift;
	if (!$self->{POST}) {
		$self->{FIELDS}->{country} = $SSL->{'country'};
		$self->{FIELDS}->{state} = $SSL->{'state'};
		$self->{FIELDS}->{loc} = $SSL->{'loc'};
		$self->{FIELDS}->{orga} = $SSL->{'orga'};
		$self->{FIELDS}->{orgaunit} = $SSL->{'orgaunit'};
	}
	my $res = <<EOF;
<div class="title">Add New Client</div>
EOF
	if ($self->{ERROR}) {
		$res .= '<div class="errorContainer">';
		my @err = ();
		foreach(@{$self->{ERROR}}) {
			@err = $self->trans($_);
			if (ref $err[0] eq 'ARRAY') {
				foreach (@{$err[0]}) {
					$self->{'err' . $err[0]} = ' errorMsg';
				}
			} else {
				$self->{'err' . $err[0]} = ' errorMsg';
			}

			$res .= "<div class=\"errorMsg\">" . $err[1] . "</div>";
		}
		$res .= '</div>';
	}
	my $node = $self->{FIELDS}->{node} ? ' checked':'';
	$res .= <<EOF;
<form id="addNetwork" method="post" enctype="multipart/form-data">
<input type="hidden" name="action" value="$self->{FIELDS}->{action}"/>
<input type="hidden" name="sub" value="$self->{FIELDS}->{sub}"/>
<div class="label$self->{errcountrt}">Country</div>
<div class="input"><input name="country" value="$self->{FIELDS}->{country}" /></div>
<div class="label$self->{errstate}">State</div>
<div class="input"><input name="state" value="$self->{FIELDS}->{state}" /></div>
<div class="label$self->{errloc}">Location</div>
<div class="input"><input name="loc" value="$self->{FIELDS}->{loc}" /></div>
<div class="label$self->{errorga}">Organisation</div>
<div class="input"><input name="orga" value="$self->{FIELDS}->{orga}" /></div>
<div class="label$self->{errorga}">Organisation Unit</div>
<div class="input"><input name="orgaunit" value="$self->{FIELDS}->{orgaunit}" /></div>
<div class="label$self->{errcn}">CN</div>
<div class="input"><input name="cn" value="$self->{FIELDS}->{cn}" /></div>
<div class="label$self->{erremail}">E-Mail</div>
<div class="input"><input name="email" value="$self->{FIELDS}->{email}" /></div>
<div class="label$self->{errpass}">Pass Phrase</div>
<div class="input"><input name="pass" value="$self->{FIELDS}->{pass}" /></div>
<div class="label$self->{errdate} input-group date" id="expire">Reminder Date</div>
<div class="input"><input id="expired" name="date" value="$self->{FIELDS}->{date}" class="form-control" readonly="true"/>
<button id="trigger">...</button><button id="clear" onclick="clearDate('expired'); return false;">X</button></div>
<div class="label$self->{errcomment}">Comment</div>
<div class="input"><input name="comment" value="$self->{FIELDS}->{comment}" /></div>
<div class="label$self->{errnode}">Node Client</div>
<div class="input"><input type="checkbox" name="node"$node/></div>
<div style="clear: left"></div>
<div class="label">&nbsp;</div><div style="float: left;" class="button"
	onclick="addNet(\'addClient\')">Add Client</div>
<div style="clear: left"></div>
</form>
<script type="text/javascript">
  Calendar.setup(
    {
      inputField  : "expired",       // ID of the input field
      ifFormat    : "%Y-%m-%d",    // the date format
      button      : "trigger"       // ID of the button
    }
  );
</script>
EOF
}

sub listClients {
	my $self = shift;

	my $sthc = $self->getClients();
	my $alter = 0;
	my $res = <<EOF;
<div class="title">Client List</div>
	<div id="networkList">
EOF
	unless ($self->{CLIST}) {
		$res .= '<div class="errorContainer">';
		$res .= '<div class="errorMsg">No Clients defined</div></div>';
	}

	if (ref $self->{CLIST}) {
		for (my $i = 0; $#{$self->{CLIST}} >= $i; $i++) {
			$alter = ($alter ? 0:1);
			$res .= "<div class=\"list alter_$alter\">";
			$res .= $self->formatList($self->{CLIST}[$i][0]);
			$res .= "</div>";
		}
	}


	$res .= <<EOF
	</div>
</form>
EOF
}

sub formatList {
	my $self = shift;
	my $id = shift;
	my $res = "<div id=\"netListContainer_$id\">";
	my $showInput = '';

	if ($self->{FIELDS}->{manage}) {
		$self->updateClient();
	}

	my $client = [];
	my $sthc = $self->getClient($id);
	if ($sthc->rows) {
		$self->{netsel} = ();
		while(my@rec = $sthc->fetchrow_array()) {
			@{$client} = @rec;
			$self->{netsel}{$rec[5]} = 1;
		}
	}

	unless ($self->{NETGRPLIST}) {
		my $net = OVPNADM::network->new('',$self->{DBH});
		$net->getNetworkGrps();
		$self->{NETGRPLIST} = $net->{NETGRPLIST};
	}

	my $networks = '';
	for (my $i = 0; $#{$self->{NETGRPLIST}} >= $i; $i++) {
		if ($self->{netsel}{$self->{NETGRPLIST}[$i][0]}) {
			$networks .= ($networks?', ':'') . $self->{NETGRPLIST}[$i][1];
		}
	}


	my $active = $client->[4] =~ /y/i ? '':'Inactive';
	$res .= "<div class=\"cname$active\"><a href=\"\" onclick=\"showListEdit($id,'editNet');return false;\">" .
		$client->[2] . "</a></div>" .
		"<div class=\"network\">$networks</div>" .
		"<div style=\"clear: left\"></div>";

	if ($self->{ERROR}) {
		$showInput = ' style="display: block"';
		$res .= '<div class="errorContainerLists">';
		my @err = ();
		foreach(@{$self->{ERROR}}) {
			@err = $self->trans($_);
			if (ref $err[0] eq 'ARRAY') {
				foreach (@{$err[0]}) {
					$self->{'err' . $err[0]} = ' errorMsg';
				}
			} else {
				$self->{'err' . $err[0]} = ' errorMsg';
			}

			$res .= "<div class=\"errorMsg\">" . $err[1] . "</div>";
		}
		$res .= '</div>';
	}
	$res .= "<div id=\"editNet_$id\" class=\"editNetwork\"$showInput>";
	$res .= $self->formManageClient($client,$self->{NETGRPLIST},
		"editNetwork_$id","updateListEdit('editNetwork_$id','netListContainer_$id')");
	$res .= '</div></div>';

	return $res;
}

 sub getClients {
 	my $self = shift;
 	my $id = shift;
 	my $sth = $self->{DBH}->prepare("SELECT clients_id,subject,cname,email,active,DATE_FORMAT(reminder,'%Y-%m-%d'),comment FROM clients ORDER by cname,subject");
 	$sth->execute();
 	if ($sth->rows) {
 		while (my @rec = $sth->fetchrow_array) {
			push(@{$self->{CLIST}}, [@rec]);
		}
 	} else {
 		return 0;
 	}
}

sub importClient {
	my $self = shift;
	my $res = <<EOF;
	<div class="title">Import Client Cert</div>
EOF

	if ($self->{ERROR}) {
		$res .= '<div class="errorContainer">';
		my @err = ();
		foreach(@{$self->{ERROR}}) {
			@err = $self->trans($_);
			if (ref $err[0] eq 'ARRAY') {
				foreach (@{$err[0]}) {
					$self->{'err' . $err[0]} = ' errorMsg';
				}
			} else {
				$self->{'err' . $err[0]} = ' errorMsg';
			}

			$res .= "<div class=\"errorMsg\">" . $err[1] . "</div>";
		}
		$res .= '</div>';
	}
	$res .= <<EOF;
<form id="addNetwork" method="post" enctype="multipart/form-data">
<input type="hidden" name="action" value="$self->{FIELDS}->{action}"/>
<input type="hidden" name="sub" value="$self->{FIELDS}->{sub}"/>
<div class="label$self->{errcert}">Client Cert</div>
<div class="select"><input type="file" name="cert" value="" /></div>
<div class="beforeSelect"></div>
<div class="label$self->{errkey}">Client Key</div>
<div class="select"><input type="file" name="key" value="" /></div>
<div style="clear: left"></div>
<div class="beforeSelect"></div>
<div class="label$self->{errpass}">Key Passphrase</div>
<div class="select"><input type="text" name="pass" value="" /></div>
<div style="clear: left"></div>
<div style="float: left;" class="button"
	onclick="addNet(\'importCert\')">Import Cert</div>
<div style="clear: left"></div>
</form>
EOF
}

sub verifyRequest {
	my $self = shift;
	if (!$self->{FIELDS}->{email}) {
		push(@{$self->{ERROR}}, 'no_email');
	} else {
		unless ($self->checkEmail($self->{FIELDS}->{email})) {
			push(@{$self->{ERROR}}, 'email_not_valid');
		}
	}
	if (!$self->{FIELDS}->{cn}) {
		push(@{$self->{ERROR}}, 'no_cn');
	}
	if (!$self->{FIELDS}->{orga}) {
		push(@{$self->{ERROR}}, 'no_orga');
	}
	if (!$self->{FIELDS}->{pass} && !$self->{FIELDS}->{node}) {
		push(@{$self->{ERROR}}, 'no_pass');
	}
	return $self->{ERROR} ? 0:1;
}

sub checkEmail {
   my $self = shift;
   my $val = shift;
   if ($val =~ /^\s*(".*?")\s+<(\S+)>\s*$/) {
      my @at = split('@', $2);
      return 0 unless ($#at == 1);
      return 0 unless ($at[1] =~ /\S+\.\S+/);
      return $val;
   } elsif ($val =~ /^\s*(\S+)\s*$/) {
      my @at = split('@', $1);
      return 0 unless ($#at == 1);
      return 0 unless ($at[1] =~ /\S+\.\S+/);
      return $val;
   } else {
      return 0;
   }
}

sub verifyCert {
	my $self = shift;
	if (!$self->{FIELDS}->{cert}) {
		push(@{$self->{ERROR}}, 'no_cert_file');
	}
	if (!$self->{FIELDS}->{key}) {
		push(@{$self->{ERROR}}, 'no_key_file');
	}
	unless ($self->{ERROR}) {
		my $time = time;
		open(CERT, ">/tmp/cert-$time.pem");
		print CERT $self->{FIELDS}->{cert};
		close(CERT);
		open(KEY, ">/tmp/key-$time.pem");
		print KEY $self->{FIELDS}->{key};
		close(KEY);
		my $test = $self->{SSL}->verifyCerts("/tmp/cert-$time.pem","/tmp/key-$time.pem",$self->{FIELDS}->{pass});
		if ($test) {
			push(@{$self->{ERROR}}, $test);
			unlink "/tmp/key-$time.pem";
			unlink "/tmp/cert-$time.pem";
			return;
		}
		$self->{CERT} = $self->{SSL}->getClientCerts("/tmp/cert-$time.pem","/tmp/key-$time.pem");

		$self->{KEY} = $self->{SSL}->{KEY};
		$self->{CA} = $self->{SSL}->{CA};
		unlink "/tmp/key-$time.pem";
		unlink "/tmp/cert-$time.pem";
		return 1;
	}
}

sub verifyCreatedCert {
	my $self = shift;
	my $cert = shift;
	my $test = $self->{SSL}->verifyCerts($cert->[0],$cert->[1],$self->{FIELDS}->{pass});
	if ($test) {
		push(@{$self->{ERROR}}, $test);
		unlink $cert->[0];
		unlink $cert->[1];
		unlink $cert->[2];
		return;
	}
	$self->{CERT} = $self->{SSL}->getClientCerts($cert->[0],$cert->[1]);

	$self->{KEY} = $self->{SSL}->{KEY};
	$self->{CA} = $self->{SSL}->{CA};
	unlink $cert->[0];
	unlink $cert->[1];
	unlink $cert->[2];
	return 1;
}

sub createCert {
	my $self = shift;
	my $ssl = $self->{SSL};
	my $f = $self->{FIELDS};
	capture { $ssl->create_client_cert({
	   	'COUNTRY' => $f->{country},
	   	'STATE' => $f->{state},
	   	'LOCATION' => $f->{loc},
	   	'O' => $f->{orga},
	   	'OU' =>  $f->{orgaunit},
	  	'CN' => $f->{cn},
	   	'EMAIL' => $f->{email},
	   	'NODE', ($f->{node} ? 1:0),
	   	'PASS', $f->{pass},
   		});
	};
	my $id = '';
	if ($#{$ssl->{ERRORS}} == -1) {
		my $test = $self->verifyCreatedCert($ssl->{tmpcert});
		unless ($test) {
			push(@{$self->{ERROR}}, 'cert_verify');
			return;
		}
		$id = $self->saveImportedClient();
	} else {
		push(@{$self->{ERROR}}, 'cert_create');
		return "$#{$ssl->{ERRORS}}";
	}
	return $id;
}

sub saveImportedClient {
	my $self = shift;
	my $c = $self->{CERT};
	my $id = $self->addCert();
	my $ssl = $self->{SSL};
	open(CERT, ">$ssl->{PARA}->{baseDir}/certs/$c->{SERIAL}.cert.pem") || die;
	print CERT $c->{TEXT};
	close(CERT);

	open(KEY, ">$ssl->{PARA}->{baseDir}/certs/$c->{SERIAL}.key.pem")  || die;
	print KEY $ssl->{KEY};
	close(KEY);
	return $id;
}

sub addCert {
	my $self = shift;
	my $c = $self->{CERT};
	my $sth = $self->{DBH}->prepare("INSERT INTO clients (clients_id,subject,country,state,orga,orgunit," .
                "cname,email,pass,serial,active,cert,certkey,reminder,comment,auth_secret) VALUES (0,?,?,?,?,?,?,?,?,?,'y',?,?,?,?,?)");
   if (!$self->{FIELDS}->{date}) {
   	$self->{FIELDS}->{date} = '2033-12-31 00:00:00';
   }
   my $auth_secret = $self->createAuthentifcaterSecret();
   $sth->execute($c->{SUBJECT},$c->{C},$c->{ST},$c->{O},$c->{OU},$c->{CN},$c->{emailAddress},
   	$self->{FIELDS}->{pass},$c->{SERIAL},$c->{TEXT},$c->{KEY},$self->{FIELDS}->{date},$self->{FIELDS}->{comment},$auth_secret);
	$sth->{mysql_insertid};
}

sub getClient {
	my $self = shift;
	my $id = shift;
	my $sth = $self->{DBH}->prepare("SELECT clients_id,subject,cname,email,active,grpid,DATE_FORMAT(reminder,'%Y-%m-%d'),comment FROM clients " .
		"LEFT JOIN clients2groups ON clients_id = cid WHERE clients_id = ?");
	$sth->execute($id);
	if ($sth->rows) {
		return $sth;
	}
	return;
}

sub updateClient {
	my $self = shift;
	my $sth = $self->{DBH}->prepare("UPDATE clients SET active = ?,reminder = ?,comment = ? WHERE clients_id = ?");
	$sth->execute(($self->{FIELDS}->{active} ? 'y':'n'), $self->{FIELDS}->{date}, $self->{FIELDS}->{comment}, $self->{FIELDS}->{manage});
	$sth = $self->{DBH}->prepare("DELETE FROM clients2groups WHERE cid = ?");
	$sth->execute($self->{FIELDS}{manage});
	$self->insertClient2Group($self->{FIELDS}{manage});
}

sub insertClient2Group {
	my $self = shift;
	my $cid = shift;
	my $sth = $self->{DBH}->prepare("INSERT INTO clients2groups VALUES (?,?)");
	if ($self->{FIELDS}->{netgrp}) {
		if (ref $self->{FIELDS}->{netgrp}) {
			foreach(@{$self->{FIELDS}->{netgrp}}) {
				$sth->execute($cid,$_);
			}
		} else {
			$sth->execute($cid,$self->{FIELDS}->{netgrp});
		}
	}
}

sub manage_client {
	my $self = shift;
	$self->{CLIENTID} = shift;

	if ($self->{FIELDS}->{manage}) {
		$self->updateClient();
	}
	my $client = [];
	my $sthc = $self->getClient($self->{CLIENTID});
	if ($sthc->rows) {
		while(my@rec = $sthc->fetchrow_array()) {
			@{$client} = @rec;
			$self->{netsel}{$rec[5]} = 1;
		}
	}

	my $net = OVPNADM::network->new('',$self->{DBH});
	$net->getNetworkGrps();



	my $res = <<EOF;
<div class="title">Manage Client</div>
EOF
	if ($self->{ERROR}) {
		$res .= '<div class="errorContainer">';
		my @err = ();
		foreach(@{$self->{ERROR}}) {
			@err = $self->trans($_);
			if (ref $err[0] eq 'ARRAY') {
				foreach (@{$err[0]}) {
					$self->{'err' . $err[0]} = ' errorMsg';
				}
			} else {
				$self->{'err' . $err[0]} = ' errorMsg';
			}

			$res .= "<div class=\"errorMsg\">" . $err[1] . "</div>";
		}
		$res .= '</div>';
	}
	$res .= $self->formManageClient($client,$net->{NETGRPLIST});
}

sub formManageClient {
	my $self = shift;
	my $client = shift;
	my $netgroup = shift;
	my $formid = shift || 'addNetwork';
	my $action = shift || "addNet(\'addClient\')";
	my $optionAvail = '';
	for (my $i = 0; $#{$netgroup} >= $i; $i++) {
		my $select = $self->{netsel}{$netgroup->[$i][0]} ? ' selected':'';
		$optionAvail .= "<option value=\"$netgroup->[$i][0]\"
			title=\"$netgroup->[$i][1]\"$select>$netgroup->[$i][1]</option>\n";
	}
	my $exportTo = $action ? "editNet_$client->[0]":'dataContainer';
	my $active = ($client->[4] =~ /y/i ? ' checked':'');

	# get the last login attempt
	my $lsth = $self->{DBH}->prepare("SELECT DATE_FORMAT(login,'%b %d %Y %h:%i %p'),state FROM clientlogin WHERE cid = $client->[0] ORDER BY login DESC LIMIT 1");
	$lsth->execute();
	my @login = $lsth->fetchrow_array() if ($lsth->rows);

	my $res .= <<EOF;
<form id="$formid" method="post" enctype="multipart/form-data">
<input type="hidden" name="action" value="$self->{FIELDS}->{action}"/>
<input type="hidden" name="sub" value="$self->{FIELDS}->{sub}"/>
<input type="hidden" name="manage" value="$client->[0]"/>
<input type="hidden" name="confirmed" value="0"/>
<div class="certDetails">
<strong>CN: $client->[2]</strong><br/>
E-Mail: $client->[3]<br/>
Subject: $client->[1]<br/>
EOF

if ($login[0]) {
   $res .= "Last Login: $login[0], active state '$login[1]'<br/>";
}

   $res .= <<EOF;
</div>

<div class="beforeSelect"></div>
<div class="label$self->{errpass}">Available Groups</div>
<div class="select"><select name="netgrp" size="5" multiple>$optionAvail</select></div>
<div class="beforeSelect"></div>
<div class="label$self->{erractive}">VPN Active:
<input type="checkbox" name="active" value="y"$active/></div>
<div class="label$self->{errdate} input-group date" id="expire$formid">Reminder Date</div>
<div class="input"><input id="expired$formid" name="date" value="$client->[6]" class="form-control" readonly="true"/>
<button id="trigger$formid">...</button><button id="clear" onclick="clearDate('expired$formid'); return false;">X</button></div>
<div class="label$self->{errcomment}">Comment</div>
<div class="input"><input name="comment" value="$client->[7]" /></div>
<div style="clear: left"></div>
<div style="float: left;" class="button"
	onclick="$action">Update Client</div>
<div style="float: left; margin-left: 5px" class="button"
	onclick="exportClient('$formid',$client->[0])">Export Client Config</div>
<div style="float: left; margin-left: 5px" class="button"
	onclick="revokeClient('$formid',$client->[0])">Revoke Client</div>
<div style="clear: left"></div>
<div class="exportClient" id="exportClient_$client->[0]"></div>
</form>
<script type="text/javascript">
  Calendar.setup(
    {
      inputField  : "expired$formid", // ID of the input field
      ifFormat    : "%Y-%m-%d",    // the date format
      button      : "trigger$formid"       // ID of the button
    }
  );
</script>
EOF
}

sub trans {
	my $self = shift;
	my $text = shift;
	my %trans = (
		'empty_cn', ['cn','- Common Name can not be empty'],
		'no_cert_file', ['cert','- Please provide a certificate file'],
		'no_key_file', ['key','- Please provide a key file'],
		'error_cert', ['cert','- Cert file is not valid'],
		'error_key', ['key','- Key file is not valid or passphrase is not valid'],
		'error_cert_key', [['cert','key'],'- Cert and key do not match'],
		'error_key_adding_pass', ['key','- Key file could not add password'],
		'error_cert_not_ours', ['cert', 'This certificate was not signed by our ca'],
		'error_cert_revoked', ['cert', 'This certificate is revoked'],
		'cert_ok', ['cert', "This certificate is ok"],
		'no_email', ['email', "E-Mail needs to be supplied"],
		'no_cn', ['cn', "CN needs to be supplied"],
		'no_orga', ['orga', "Organization needs to be supplied"],
		'no_pass', ['pass', "Pass Phrase required for none Node clients"],
		'email_not_valid', ['email', "Provided E-Mail Address is not valid"],
		'cert_verify', ['cn', "Could not verify new certificate"],
		'cert_create', ['cn', "Could not create new certificate"],
	);
	return @{$trans{$text}};
}

1;
