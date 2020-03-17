package OVPNADM::header;

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

sub new {
    my $that = shift;
    my $class = ref($that) || $that;
    my $self = {};
    $self->{REQ} = shift;
    bless ($self,$class);
    return $self;
}

my %menus = (
    'clients' => {
        '1_create' => 'Add Client',
        '2_list' => 'List Clients',
        '3_import' => 'Import Clients',
        #'3_status' => 'Connected Clients',
      },
    'networks' => {
        '1_create' => 'Add Network',
        '2_list' => 'List Networks',
        '3_creategrp' => 'Add Group',
        '4_listgrp' => 'List Groups',
        #'5_status' => 'Network Status',
      },
      #'status' => {
      #  '1_networks' => 'Network Status',
        #'2_clients' => 'Connected Clients',
      #  }
      );

sub head {
  $self = shift;
  $self->{fields} = shift;
  my $res = <<EOF;
<!DOCTYPE html><html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en-en" lang="en-en" dir="ltr" >
<head>
   <meta http-equiv="content-type" content="text/html; charset=utf-8" />
   <title>Openvpn Admin Console</title>
	<link href="/css/def.css" rel="stylesheet" type="text/css" media="all" />
	<script type="text/javascript" src="/js/jquery-2.1.0.js"></script>
	<script type="text/javascript" src="/js/spin.js"></script>
	<script type="text/javascript" src="/js/lib.js"></script>
	<script type="text/javascript" src="/js/printThis.js"></script>
  <style type="text/css">\@import url(jscalendar/calendar-blue.css);</style>
  <script type="text/javascript" src="jscalendar/calendar.js"></script>
  <script type="text/javascript" src="jscalendar/lang/calendar-en.js"></script>
  <script type="text/javascript" src="jscalendar/calendar-setup.js"></script>
</head>
<body>
  <div id="container">
	<div id="logo"></div>
  <div id="menuContent">
EOF
  $res .= $self->menu();

  $res .=<<EOF;
  <div id="mainContent">
EOF
  $res .= $self->subMenus();

  $res .= '<div id="dataContainerWrapper"><div id="dataContainer">' . "\n";

  $self->{REQ}->content($res);
}

sub menu {
  my $self = shift;
  my ($clients, $networks,$status) = '';
  if ($self->{fields}->{action} eq 'clients') {
    $clients = ' class="active"';
    $self->{ACTION} = 'clients';   
  } elsif ($self->{fields}->{action} eq 'networks') {
    $networks = ' class="active"';
    $self->{ACTION} = 'networks';   
  } elsif ($self->{fields}->{action} eq 'status') {
    $status = ' class="active"';  
    $self->{ACTION} = 'status'; 
  } else {
    $clients = ' class="active"';
    $self->{ACTION} = 'clients'; 
  }
   
  return <<EOF;
<div id="menu_container">
<div id="ovpnlogo"><img src="/images/ovpnlogo.png" /></div>
<div id="menuMain"><ul class="menu">
<li$clients><a href="?action=clients">VPN Clients</a></li>
<li$networks><a href="?action=networks">Networks</a></li>
<!--li$status><a href="?action=status">Status</a></li-->
</ul></div>   
<div style="clear: both"></div>
</div>
EOF
}

sub subMenus {
  my $self = shift;
   
  my $res .= <<EOF;
<div id="submenu_container" style="clear: left;">
<ul class="submenu">
EOF

  foreach (sort keys %{$menus{$self->{ACTION}}}) {
    my $active = '';
    if ($self->{fields}->{sub} eq $_) {
      $self->{SUBACTION} = $_;
      $active = ' class="active"';
    }
    $res .= "<li$active><a href=\"?action=$self->{ACTION}&sub=$_\">$menus{$self->{ACTION}}{$_}</a></li>\n";
  }

  $res .= <<EOF;
</ul>
</div>
EOF
}

sub foot {
  my $self = shift;
	$self->{REQ}->content(<<EOF);
  </div></div><div style="clear: left"></div></div></div></div>
  <div id="add_panel"></div>
</body>
</html>
EOF
}
1;