#!/usr/bin/perl

#    © 2017 / Lembke Computer Consulting GmbH /  http://www.lcc.ch
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
	
}

use DBI;

my $dbh = DBI->connect(
    "dbi:mysql:dbname=ovpn-admin", 
    "dbuser", "password",
     {RaiseError => 0, PrintError => 1, mysql_enable_utf8 => 1}
 ) or die "Connect to database failed.";

my @args = @ARGV;


my $sth = $dbh->prepare("SELECT clients_id,cname,reminder,comment FROM clients WHERE reminder < now() and active = 'y'");
$sth->execute();

if ($sth->rows) {
   my $reminders = <<eof;
   Dear VPN Manager

   the following vpn certificates have passed the reminder date. 
   Please review them and act upon them as required.

   http://192.168.67.1/

   you friendly monitor

eof

   while (my @rec = $sth->fetchrow_array) {
      $reminders .= "cname: $rec[1], reminder date: $rec[2], comment: $rec[3]\n";
   }


   open(SENDMAIL, "|/usr/sbin/sendmail -bm -t vpnadm\@youdomain.com" ) || die;
   print SENDMAIL "From: noreply\@yourdomain.com\n";
   print SENDMAIL "To: vpnadm\@yourdomain.com\n";
   print SENDMAIL "Subject: VPN Console due reminders\n\n";
   print SENDMAIL "$reminders\n.\n";
   close (SENDMAIL) ;
}

