package OVPNADM::network;

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
use Data::Validate::IP qw(is_ipv4 is_innet_ipv4 is_private_ipv4);

sub new {
	my $that = shift;
	my $class = ref($that) || $that;
	my $self = {};
	$self->{FIELDS} = shift;
	$self->{DBH} = shift;
	bless ($self,$class);
	return $self;
}

sub addNetworkGrp {
	my $self = shift;
	my $res = <<EOF;
<div class="title">Add New Group</div>
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
	$self->getNetworks();
	my $optionAvail = '';
	my $optionSelect = '<option>';
	if (ref $self->{FIELDS}->{selNet}) {
		foreach(@{$self->{FIELDS}->{selNet}}) {
			$self->{SELNET}{$_} = ' selected';
		}
	} else {
		$self->{SELNET}{$self->{FIELDS}->{selNet}} = ' selected';
	}
	for (my $i = 0; $#{$self->{NETLIST}} >= $i; $i++) {
		$optionAvail .= "<option value=\"$self->{NETLIST}[$i][0]\" 
			title=\"$self->{NETLIST}[$i][2] / $self->{NETLIST}[$i][3]\"$self->{SELNET}{$self->{NETLIST}[$i][0]}>$self->{NETLIST}[$i][1]</option>\n";
	}
	$res .= <<EOF;
<form id="addNetwork" method="post" enctype="multipart/form-data">
<input type="hidden" name="action" value="$self->{FIELDS}->{action}"/>
<input type="hidden" name="sub" value="$self->{FIELDS}->{sub}"/>
<div class="label$self->{errgrpName}">Group Name</div>
<div class="select"><input name="grpName" value="$self->{FIELDS}->{grpName}" /></div>
<div class="beforeSelect"></div>
<div class="selection">
<div class="label$self->{errnetAddr}">Select Networks</div>
<div class="select"><select name="selNet" size="5" multiple>$optionAvail</select></div>
</div>
<!--div class="selection">
<div class="addRemove">
<div class="button">&raquo;</div>
<div class="button">&laquo;</div>
</div>
</div>
<div class="selection">
<div class="label$self->{errselNet}">Selected Networks</div>
<div class="select"><select name="selNets" size="5" multiple>$optionSelect</select></div>
</div-->
<div style="clear: left"></div>
<div style="float: left;" class="button" 
	onclick="addNet(\'addGroup\')">Add Group</div>
<div style="clear: left"></div>
</form>
EOF
}

sub addNetwork {
	my $self = shift;
	my $res = <<EOF;
<div class="title">Add New Network</div>
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
<div class="label$self->{errnetName}">Network Name</div>
<div class="input"><input name="netName" value="$self->{FIELDS}->{netName}" /></div>
<div class="label$self->{errnetAddr}">Network Address</div>
<div class="input"><input name="netAddr" value="$self->{FIELDS}->{netAddr}" /></div>
<div class="label$self->{errnetMask}">Network Mask</div>
<div class="input"><input name="netMask" value="$self->{FIELDS}->{netMask}" /></div>
<div style="clear: left"></div>
<div class="label">&nbsp;</div><div style="float: left;" class="button" 
	onclick="addNet(\'addNetwork\')">Add Network</div>
<div style="clear: left"></div>
</form>
EOF
}

sub verifyNetworkGrp {
	my $self = shift;
	my $id = shift;
	my $nets = $self->getNetworkGrps();
	if ($nets) {
		if ($self->{NETGRPNAMES}{$self->{FIELDS}{grpName}}) {
			if ($id && $self->{NETGRPNAMES}{$self->{FIELDS}{grpName}}[0][0] != $id) {
				push(@{$self->{ERROR}}, 'exists_grpname');
			} elsif (!$id) {
				push(@{$self->{ERROR}}, 'exists_grpname');
			}
		}
	}
	if ($self->{FIELDS}{grpName} =~ /^\s*$/) {
		push(@{$self->{ERROR}}, 'empty_grpname');
	}
	return ($self->{ERROR} ? 0:1);
}

sub verifyNetwork {
	my $self = shift;
	my $id = shift;
	my $nets = $self->getNetworks();
	if ($nets) {
		if ($self->{NETNAMES}{$self->{FIELDS}{netName}}) { 
			if ($id && $self->{NETNAMES}{$self->{FIELDS}{netName}}[0][0] != $id) {
				push(@{$self->{ERROR}}, 'exists_netname');
			} elsif (!$id) {
				push(@{$self->{ERROR}}, 'exists_netname');
			}
		}
		if ($self->{NETWORKS}{$self->{FIELDS}{netAddr}}) {
			if ($id && $self->{NETWORKS}{$self->{FIELDS}{netAddr}}[0][0] != $id) {
				push(@{$self->{ERROR}}, 'exists_netaddr');
			} elsif (!$id) {
				push(@{$self->{ERROR}}, 'exists_netaddr');
			}
		}
	}
	if (!$self->{FIELDS}{netName}) {
		push(@{$self->{ERROR}}, 'empty_netname');	
	}
	if (!$self->{FIELDS}{netAddr}) {
		push(@{$self->{ERROR}}, 'empty_netaddr');	
	}
	if (!$self->{FIELDS}{netMask}) {
		push(@{$self->{ERROR}}, 'empty_netmask');	
	}
	if (!is_ipv4($self->{FIELDS}{netAddr})) {
		push(@{$self->{ERROR}}, 'noipv4_netaddr');
	}
	# if (!is_private_ipv4($self->{FIELDS}{netAddr})) {
	# 	push(@{$self->{ERROR}}, 'notprivat_netaddr');
	# }
	if (!is_ipv4($self->{FIELDS}{netMask})) {
		push(@{$self->{ERROR}}, 'noipv4_netmask');
	}
	if (!is_innet_ipv4($self->{FIELDS}{netAddr},"$self->{FIELDS}{netAddr}/$self->{FIELDS}{netMask}")) {
		push(@{$self->{ERROR}}, 'notvalid_network');
	}
	return ($self->{ERROR} ? 0:1);
}

sub insertNetworkGrp {
	my $self = shift;
	my $sth = $self->{DBH}->prepare("INSERT INTO network_groups 
			(network_groups_id,grpname) VALUES (0,?)");
	$sth->execute($self->{FIELDS}{grpName});
	my $grpid = $sth->{mysql_insertid};
	if ($self->{FIELDS}->{selNet}) {
		$self->insertGrp2Net($grpid);
		return $grpid;
	} else {
		return $grpid;
	}
}

sub insertGrp2Net {
	my $self = shift;
	my $grpid = shift;
	my $sth = $self->{DBH}->prepare("INSERT INTo grp2network VALUES (?,?)");
	if ($self->{FIELDS}->{selNet}) {
		if (ref $self->{FIELDS}->{selNet}) {
			foreach(@{$self->{FIELDS}->{selNet}}) {
				$sth->execute($grpid,$_);
			}
		} else {
			$sth->execute($grpid,$self->{FIELDS}->{selNet});
		}
	}
}


sub insertNetwork {
	my $self = shift;
	my $sth = $self->{DBH}->prepare("INSERT INTO networks 
			(networks_id,name,network,mask) VALUES (0,?,?,?)");
	$sth->execute($self->{FIELDS}{netName},$self->{FIELDS}{netAddr},$self->{FIELDS}{netMask});
	return $sth->{mysql_insertid};
}

sub updateNetwork {
	my $self = shift;
	my $sth = $self->{DBH}->prepare("UPDATE networks set name = ?, network = ?, mask = ? WHERE networks_id = ?");
	$sth->execute($self->{FIELDS}{netName},$self->{FIELDS}{netAddr},$self->{FIELDS}{netMask},$self->{FIELDS}{netid});
}

sub updateNetworkGrp {
	my $self = shift;
	my $sth = $self->{DBH}->prepare("UPDATE network_groups set grpname = ? WHERE network_groups_id = ?");
	$sth->execute($self->{FIELDS}{grpName},$self->{FIELDS}{netgrpid});
	$sth = $self->{DBH}->prepare("DELETE FROM grp2network WHERE grpid = ?");
	$sth->execute($self->{FIELDS}{netgrpid});
	$self->insertGrp2Net($self->{FIELDS}{netgrpid});
}

sub deleteNetwork {
	my $self = shift;
	my $id = shift;
	my $sth = $self->{DBH}->prepare("DELETE FROM networks WHERE networks_id = ?");
	$sth->execute($id);
}

sub deleteNetworkGrp {
	my $self = shift;
	my $id = shift;
	my $sth = $self->{DBH}->prepare("DELETE FROM network_groups WHERE network_groups_id = ?");
	$sth->execute($id);
	$sth = $self->{DBH}->prepare("DELETE FROM grp2network WHERE grpid = ?");
	$sth->execute($id);
}

sub showConfirmDelete {
	my $self = shift;
	my $id = shift;
	my $confirm = <<EOF;
<div class="confirmDelete" style="display:block">
<div class="button listEdit" onclick="confirmDelete('editNetwork_$id','netListContainer_$id');">delete network</div>
<div class="button listEdit" onclick="cancelDelete('editNetwork_$id','netListContainer_$id');">cancel</div>
<div style=\"clear: left\"></div>
</div>
EOF
	my $res .= $self->formatList($id,$confirm);
}

sub showConfirmDeleteGrp {
	my $self = shift;
	my $id = shift;
	my $confirm = <<EOF;
<div class="confirmDelete" style="display:block">
<div class="button listEdit" onclick="confirmDeleteGrp('editGroup_$id','netListContainer_$id');">delete group</div>
<div class="button listEdit" onclick="cancelDelete('editGroup_$id','netListContainer_$id');">cancel</div>
<div style=\"clear: left\"></div>
</div>
EOF
	my $res .= $self->formatListGrp($id,$confirm);
}

sub listNetworkGrp {
	my $self = shift;
	$self->getNetworks();
	$self->getNetworkGrps();

	my $alter = 0;
	my $res = <<EOF;
<div class="title">Network Groups</div>
	<div id="networkList">
EOF
	unless ($self->{NETGRPLIST}) {
		$res .= '<div class="errorContainer">';
		$res .= '<div class="errorMsg">No Networks defined</div></div>';
	}

	if (ref $self->{NETGRPLIST}) {
		for (my $i = 0; $#{$self->{NETGRPLIST}} >= $i; $i++) {
			$alter = ($alter ? 0:1);
			$res .= "<div class=\"list alter_$alter\">";
			$res .= $self->formatListGrp($self->{NETGRPLIST}[$i][0]);
			$res .= "</div>";
		}
	}

	$res .= <<EOF
	</div>
</form>
EOF
}

sub formatListGrp {
	my $self = shift;
	my $id = shift;
	my $action = shift;
	my $res = "<div id=\"netListContainer_$id\">";
	my $showInput = '';

	$res .= "<div class=\"name\"><a href=\"\" onclick=\"showListEdit($id,'editNet');return false;\">" . 
		$self->{NETGRPID}{$id}[1] . "</a></div>";

	if ($self->getNetGrpMembers($id)) {
		$res .= "<div class=\"network\" style=\"clear: left\">"; 
		for (my $i = 0; $#{$self->{NETGRPMEMBERS}}>=$i;$i++) {
			$res .= ($i > 0 ? ', ':'');
			$res .= "<span class=\"netMembers\"><strong>$self->{NETGRPMEMBERS}[$i]->[1]</strong> " .
				"($self->{NETGRPMEMBERS}[$i]->[2]/$self->{NETGRPMEMBERS}[$i]->[3])</span>"; 
		}
		$res .= "</div>\n";
	}
	$res .=	"<div style=\"clear: left\"></div>";

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

	my $optionAvail = '';
	for (my $i = 0; $#{$self->{NETLIST}} >= $i; $i++) {
		$optionAvail .= "<option value=\"$self->{NETLIST}[$i][0]\" 
			title=\"$self->{NETLIST}[$i][2] / $self->{NETLIST}[$i][3]\" " .
			"$self->{NETGRPMEMBERSSEL}{$self->{NETLIST}[$i][0]}>$self->{NETLIST}[$i][1]</option>\n";
	}

	$res .= "<div id=\"editNet_$id\" class=\"editNetwork\"$showInput>".
		"<form id=\"editGroup_$id\" method=\"post\" 
			enctype=\"multipart/form-data\">" .
		"<input type=\"hidden\" name=\"action\" value=\"$self->{FIELDS}->{action}\">" .
		"<input type=\"hidden\" name=\"sub\" value=\"$self->{FIELDS}->{sub}\">" .
		"<input type=\"hidden\" name=\"netgrpid\" value=\"$id\">" .
		"<input type=\"hidden\" name=\"confirmed\" value=0>" .
		"<div class=\"beforeSelect\"></div>" .
		"<div class=\"name\">" .
			"<input type=\"text\" name=\"grpName\" value=\"$self->{NETGRPID}{$id}[1]\"></div>" .
		"<div class=\"beforeSelect\"></div>" .
		"<div class=\"select\"><select multiple size=\"5\" name=\"selNet\">$optionAvail</select></div>";
	$res .=	"<div class=\"button\" style=\"float: left;\"" .
			"onclick=\"updateListEdit('editGroup_$id','netListContainer_$id')\">update group</div>" .
		"</form></div>\n$action<div style=\"clear: left\"></div></div>";
	return $res;
}

sub listNetworks {
	my $self = shift;
	$self->getNetworks();

	my $alter = 0;
	my $res = <<EOF;
<div class="title">Network List</div>
	<div id="networkList">
EOF
	unless ($self->{NETLIST}) {
		$res .= '<div class="errorContainer">';
		$res .= '<div class="errorMsg">No Networks defined</div></div>';
	}

	if (ref $self->{NETLIST}) {
		for (my $i = 0; $#{$self->{NETLIST}} >= $i; $i++) {
			$alter = ($alter ? 0:1);
			$res .= "<div class=\"list alter_$alter\">";
			$res .= $self->formatList($self->{NETLIST}[$i][0]);
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
	my $action = shift;
	my $res = "<div id=\"netListContainer_$id\">";
	my $showInput = '';

	$res .= "<div class=\"name\"><a href=\"\" onclick=\"showListEdit($id,'editNet');return false;\">" . 
		$self->{NETID}{$id}[1] . "</a></div>" .
		"<div class=\"network\">" . $self->{NETID}{$id}[2] . ' / ' . $self->{NETID}{$id}[3]. "</div>" .
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

	$res .= "<div id=\"editNet_$id\" class=\"editNetwork\"$showInput>".
		"<form id=\"editNetwork_$id\" method=\"post\" 
			enctype=\"multipart/form-data\">" .
		"<input type=\"hidden\" name=\"action\" value=\"$self->{FIELDS}->{action}\">" .
		"<input type=\"hidden\" name=\"sub\" value=\"$self->{FIELDS}->{sub}\">" .
		"<input type=\"hidden\" name=\"netid\" value=\"$id\">" .
		"<input type=\"hidden\" name=\"confirmed\" value=0>" .
		"<div class=\"name\">" .
			"<input type=\"text\" name=\"netName\" value=\"$self->{NETID}{$id}[1]\"></div>" .
		"<div class=\"network\">" .
			"<input type=\"text\" size=\"15\" name=\"netAddr\" value=\"$self->{NETID}{$id}[2]\"> / " .
			"<input type=\"text\" size=\"15\" name=\"netMask\" value=\"$self->{NETID}{$id}[3]\"></div>" .
		"<div class=\"button listEdit\" " .
			"onclick=\"updateListEdit('editNetwork_$id','netListContainer_$id')\">update network</div>" .
		"</form></div>\n$action<div style=\"clear: left\"></div></div>";
	return $res;
}

sub getNetworks {
	my $self = shift;
	my $sth = $self->{DBH}->prepare("SELECT networks_id,name,network,mask FROM networks ORDER BY name,network");
	$sth->execute();
	$self->{NETLIST} = ();
	if ($sth->rows) {
		while (my @rec = $sth->fetchrow_array) {
			push(@{$self->{NETLIST}}, [@rec]);
			$self->{NETID}{$rec[0]} = [@rec];
			push(@{$self->{NETNAMES}{$rec[1]}}, [@rec]);
			push(@{$self->{NETWORKS}{$rec[2]}}, [@rec]); 
		}
		return 1;
	} else {
		return 0;
	}
}

sub getNetworkGrps {
	my $self = shift;
	my $sth = $self->{DBH}->prepare("SELECT network_groups_id,grpname FROM network_groups ORDER BY grpname");
	$sth->execute();
	if ($sth->rows) {
		while (my @rec = $sth->fetchrow_array) {
			push(@{$self->{NETGRPLIST}}, [@rec]);
			$self->{NETGRPID}{$rec[0]} = [@rec];
			push(@{$self->{NETGRPNAMES}{$rec[1]}}, [@rec]);
		}
		return 1;
	} else {
		return 0;
	}
}

sub getNetGrpMembers {
	my $self = shift;
	my $grpid = shift;
	my $sth = $self->{DBH}->prepare("select networks_id,name,network,mask from grp2network " .
			"left join networks on netid=networks_id where grpid = ? order by name");

	$sth->execute($grpid);
	$self->{NETGRPMEMBERS} = ();
	$self->{NETGRPMEMBERSSEL} = ();
	if ($sth->rows) {
		while (my @rec = $sth->fetchrow_array) {
			push(@{$self->{NETGRPMEMBERS}}, [@rec]);
			$self->{NETGRPMEMBERSSEL}{$rec[0]} = ' selected';

		}
		return 1;
	}
	return 0;
}

sub trans {
	my $self = shift;
	my $text = shift;
	my %trans = (
		'empty_netname', ['netName','- Network name can not be empty'],
		'exists_netname', ['netName','- Network name already in use'],
		'exists_netaddr', ['netAddr','- Network address already in use'],
		'empty_netaddr', ['netAddr','- Network address can not be empty'],
		'noipv4_netaddr', ['netAddr','- Network address is not a valid IP Address'],
		'notprivat_netaddr', ['netAddr','- Network address is not from a private IP range'],
		'empty_netmask', ['netMask','- Network mask can not be empty'],
		'noipv4_netmask', ['netMask','- Network Mask is not a valid IP Mask (xxx.xxx.xxx.xxx)'],
		'notvalid_network', [['netMask','netAddr'],'- Address and Mask are not vaild'],
		'exists_grpname', ['grpName', '- Network Group already exists'],
		'empty_grpname', ['grpName', '- Network Group can not be empty'],
	);
	return @{$trans{$text}};
}

1;