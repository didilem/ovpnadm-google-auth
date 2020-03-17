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
#


BEGIN {
	use vars qw($VERSION $LIFETIME $DEBUG $MTIME $CIPHER);
	# Version of this engine
	push @INC, '/etc/openvpn/ovpnadm/lib';
	$VERSION = '1.0';
	$DEBUG = 1;
	$MTIME = undef;
	
}

binmode STDOUT, ":encoding(UTF-8)";

use strict;
use Capture::Tiny qw/capture/;

use HtmlRequest;
use Post;
use OVPNADM::config;
use OVPNADM::header;
use OVPNADM::network;
use OVPNADM::client;

use DBI;

my $dbh = DBI->connect(
    "dbi:mysql:dbname=$DBH->{'db'};host=$DBH->{'host'}", 
    "$DBH->{'user'}", "$DBH->{'pass'}",
     {RaiseError => 0, PrintError => 1, mysql_enable_utf8 => 1}
 ) or die "Connect to database failed.";

my $r = HtmlRequest->new;
my $header = OVPNADM::header->new($r);

# We always send text/html content in the charset of UTF-8
$r->content_type('text/html; charset=utf-8');
my $f = {};
my $p = {};
my $fields = {};

if ($r->method =~ /get|head/i) {
   # Initialize the form
   $f = $r->form;
   # Push the form in a format which can be parsed easly
   $p = Post->new($f->get);
   check_input();
   $header->head($fields);
   if ($fields->{action} eq 'networks') {
      my $net = OVPNADM::network->new($fields,$dbh);
      if ($fields->{sub} =~ /create$/) {
         $r->content($net->addNetwork);
      } elsif ($fields->{sub} =~ /list$/) {
         $r->content($net->listNetworks());
      } elsif ($fields->{sub} =~ /creategrp$/) {
         $r->content($net->addNetworkGrp);
      } elsif ($fields->{sub} =~ /listgrp$/) {
         $r->content($net->listNetworkGrp());
      } else {
         $r->content($net->listNetworks());
      }
   } elsif ($fields->{action} eq 'clients') {
      my $client = OVPNADM::clients->new($fields,$dbh);
      if ($fields->{sub} =~ /create$/) {
         $r->content($client->addClient);
      } elsif ($fields->{sub} =~ /list$/) {
         $r->content($client->listClients());
      } elsif ($fields->{sub} =~ /import$/) {
         $r->content($client->importClient());
      } else {
         $r->content($client->listClients());
      }    
   } else {
      $r->redirect('/?action=clients&sub=2_list');
   }
   $header->foot();
} elsif ($r->method =~ /post/i) {
   $f = $r->multiform; 
   $p = Post->new($f->get);
   check_input();
   if ($fields->{action} eq 'networks') {
      my $net = OVPNADM::network->new($fields,$dbh);
      if ($fields->{sub} =~ /create$/) {
         my $test = $net->verifyNetwork();
         if ($test) {
            my $id = $net->insertNetwork();
            $r->content("added Network $fields->{netName} with id $id");
         } else {
            $r->content($net->addNetwork);
         }
      } elsif ($fields->{sub} =~ /creategrp$/) {
         my $test = $net->verifyNetworkGrp();
         if ($test) {
            my $id = $net->insertNetworkGrp();
            $r->content("added Network Group $fields->{grpName} with id $id");
         } else {
            $r->content($net->addNetworkGrp);
         }
      } elsif ($fields->{sub} =~ /list$/) {
         if ($fields->{netName}  =~ /^\s*$/) {
            $net->getNetworks();
            if ($fields->{confirmed} == 1) {
               $net->deleteNetwork($fields->{netid});
               $r->content("Deleted network: $net->{NETID}{$fields->{netid}}[1]");
            } else {
               $r->content($net->showConfirmDelete($fields->{netid}));
            }
         } else {
            my $test = $net->verifyNetwork($fields->{netid});
            if ($test) {
               my $id = $net->updateNetwork();
               $net->getNetworks();
               $r->content($net->formatList($fields->{netid}));
            } else {
               $r->content($net->formatList($fields->{netid}));
            }
         }

      } elsif ($fields->{sub} =~ /listgrp$/) {
         $net->getNetworks();
         $net->getNetworkGrps();
         if ($fields->{grpName}  =~ /^\s*$/) {
            if ($fields->{confirmed} == 1) {
               $net->deleteNetworkGrp($fields->{netgrpid});
               $r->content("Deleted network group: $net->{NETGRPID}{$fields->{netgrpid}}[1]");
            } else {
               $r->content($net->showConfirmDeleteGrp($fields->{netgrpid}));
            }
         } else {
            my $test = $net->verifyNetworkGrp($fields->{netgrpid});
            if ($test) {
               my $id = $net->updateNetworkGrp();
               $net->getNetworks();
               $net->getNetworkGrps();
               $r->content($net->formatListGrp($fields->{netgrpid}));
            } else {
               $r->content($net->formatListGrp($fields->{netgrpid}));
            }
         }

      }
   } elsif ($fields->{action} eq 'clients') {
      my $client = OVPNADM::clients->new($fields,$dbh,1);
      if ($fields->{sub} =~ /import$/ && !$fields->{manage}) {
         my $test = $client->verifyCert();
         if ($test) {
            my $insertid = $client->saveImportedClient();
            $r->content($client->manage_client($insertid));
         } else {
            $r->content($client->importClient);
         }
      } elsif ($fields->{sub} =~ /create$/ && !$fields->{manage}) {
         my $test = $client->verifyRequest();
         if ($test) {
            my $insertid = $client->createCert();
            if ($insertid) {
               $r->content($client->manage_client($insertid));
            } else {
               $r->content($client->addClient);
            }
         } else {
            $r->content($client->addClient);
         }
      } elsif ($fields->{sub} =~ /list$/ && $fields->{manage}) {
         $r->content($client->formatList($fields->{manage}));
      } elsif ($fields->{manage}) {
         $r->content($client->manage_client($fields->{manage}));
      }
   } elsif ($fields->{action} eq 'export') {
      my $client = OVPNADM::clients->new($fields,$dbh,1);
      $r->content($client->exportConfig());
   } elsif ($fields->{action} eq 'revoke') {
      my $client = OVPNADM::clients->new($fields,$dbh,1);
      if ($fields->{confirmed} == 1) {
         $r->content($client->revokeConfig());
      } else {
         $r->content($client->showConfirmDelete());
      }
   }
}
$r->send_http_header;

$r->send_content();

sub check_input {
   my @names = $p->names();
   for my $i (0 .. $#names) {
      $names[$i] =~ /^_/ && next;
      if ($fields->{$names[$i]}) {
         if(ref($fields->{$names[$i]}) eq 'ARRAY') {
            push(@{$fields->{$names[$i]}}, xmlsave($p->val($i)));
         } else {
            $fields->{$names[$i]} = [$fields->{$names[$i]},xmlsave($p->val($i))];
         }
      } else {
         $fields->{$names[$i]} = xmlsave($p->val($i));
      }
   }
}

sub xmlsave {
   my $value = shift;
   return $value;
   $value =~ s/&/&amp;/g;
   $value =~ s/</&lt;/g;
   $value =~ s/>/&gt;/g;
   return $value;
}
1;
