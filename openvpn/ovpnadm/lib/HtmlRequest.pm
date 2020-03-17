package HtmlRequest;

#    © 2014 / Lembke Computer Consulting GmbH /  http://www.lcc.ch
#
#    This file is part of BB Cube.
#
#    BB Cube is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation GPL version 3.
#
#    BB Cube is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with BB Cube; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#

use Time::Local;
use FileHandle;
sub new {
    my $that = shift;
    my $class = ref($that) || $that;
    my $self = {};
    $self->{METHOD} = undef;
    $self->{HEADER_ONLY} = method();
    $self->{SERVER} = undef;
    $self->{GET_REMOTE_HOST} = undef;
    $self->{GET_REMOTE_PORT} = undef;
    $self->{USER} = undef;
    $self->{PROTOCOL} = undef;
    $self->{DOCUMENT_ROOT} = undef;
    $self->{MODIFIED_SINCE} = undef;
    $self->{SCRIPT} = undef;
    $self->{SERVER} = Server->new;
    $self->{URI} = undef;
    $self->{THE_REQUEST} = undef;
    $self->{HEADER_IN} = {};
    $self->{HEADER_OUT} = {};
    $self->{ERROR} = Error->new($self);
    $self->{FORM} = Form->new($self);
    $self->{MultiForm} = MultiForm->new($self);    
    $self->{QUERY_STRING} = undef;
    $self->{TIMEOUT} = 60;
    $self->{READ} = undef;
    $self->{OUT} = undef;
    $self->{INCLUDE} = undef;
    $self->{EVAL} = undef;
    $self->{EMAIL_REF} = undef;
    bless ($self,$class);
    return $self;
}

sub redirect {
   my $self = shift;
   my ($rl) = shift;
   # Redirect the client to new location
   $self->header_out('Location',"$rl");
   $self->content_type('text/html; charset=utf-8');
   return 1;
}


sub multiform {
   my $self = shift;
   return $self->{MultiForm};
}    

sub ref_email {
    my $self = shift;
    my $mail = shift;
    my $s = shift;
    my @m = split(',',$mail);
    my @v = ();
    my ($ad,$n) = '';
    my @at = ();
    foreach (@m) {
        if (m/^\s*"?(.*?)"?\s+<(\S+)>\s*$/) {
            $n = $1;
            $ad = $2;
            @at = split('@', $2);
            unless ($#at == 1) {
                push @v, $_;
                next;
            }
            unless ($at[1] =~ /\S+\.\S+/) {
                push @v, $_;
                next;
            }
            $_ = $self->quote($_);
            s/"//g; #"
            push @v, "<a href=\"mailto:$_?Subject=$s\">$n</a>"; 
        } elsif (m/^\s*(\S+)\s*$/) {
            @at = split('@', $1);
            $ad = $1;
            unless ($#at == 1) {
                push @v, $_;
                next;
            }
            unless ($at[1] =~ /\S+\.\S+/) {
                push @v, $_;
                next;
            }
            push @v, "<a href=\"mailto:$ad?Subject=$s\">$ad</a>";
        } else {
            push @v, $_;    
        }
    }
    return join ',', @v;    
}

sub gettime {
   my $self = shift;
   my $epoch = shift;
   my @days = (
      'Sun','Mon','Tue','Wed','Thu','Fri','Sat'
      );
   my @months = (
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
      );
   my ($sec,$min,$hour,$mday,$mon,$year,$wday) = 
      gmtime($epoch);
   $year = 1900 + $year;
   $mday = "0$mday" if ($mday <10);
   $hour = "0$hour" if ($hour < 10);
   $min = "0$min" if ($min <10);
   $sec = "0$sec" if ($sec <10);
   $self->{TIME} = 
      "$days[$wday], $mday $months[$mon] $year $hour:$min:$sec GMT";
   return $self->{TIME};
}

sub eval {
    my $self = shift;
    $self->timeout;
    my $f = shift;
    my $eh = '';
    $eh = $self->include($f);
    unless ($eh) {
        $self->{EVAL} = $self->{INCLUDE};
        return 0;
    }
    eval $eh || ($self->{EVAL} = "<h3>$@</h3>");
}

sub eval_error {
    my $self = shift;
    my $e = shift;
    return $self->{EVAL} unless $e;
    $self->{EVAL} = $e;   
}

sub include {
    my $self = shift;
    my $f = shift;
    if ($f =~ /\.\./) {
        $self->{INCLUDE} = "Ilegal include";
        return 0;
    }
    my $root = $self->document_root;
    my ($fh,$c) = '';
    unless ($fh = FileHandle->new("$root/$f",'<')) {
        $self->{INCLUDE} = "file: '$root/$f' not found";
        return 0;
    }
    while($_ = $fh->getline) {
        $c .= $_;
    } 
    $fh->close;
    return $c;
}

sub inc_error {
    my $self = shift;
    return $self->{INCLUDE};
}

sub content {
    my $self = shift;
    $self->{OUT} .= shift;    
}

sub send_content {
    my $self = shift;
    print $self->{OUT};    
}

sub timeout {
    my $self = shift;
    my $t = shift;
    unless (defined $t and $t) {
        return alarm $self->{TIMEOUT};
    }
    alarm $t;
}

sub form {
    my $self = shift;
    return $self->{FORM};
}

sub server {
    my $self = shift;
    return $self->{SERVER};
}

sub error {
    my $self = shift;
    return $self->{ERROR};
}

sub method {
    my $self = shift;
    if ($ENV{REQUEST_METHOD}) {
        $self->{METHOD} = $ENV{REQUEST_METHOD};
    }
    return $self->{METHOD};    
}

sub get_remote_host {
    my $self = shift;
    if ($ENV{REMOTE_ADDR}) {
        $self->{GET_REMOTE_NAME} = $ENV{REMOTE_ADDR};
    }  
    return $self->{GET_REMOTE_NAME};
}

sub user {
    my $self = shift;
    if ($ENV{REMOTE_USER}) {
        $self->{USER} = $ENV{REMOTE_USER};    
    }
    return $self->{USER};
}

sub get_remote_port {
    my $self = shift;
    if ($ENV{REMOTE_PORT}) {
        $self->{GET_REMOTE_PORT} = $ENV{REMOTE_PORT};
    }  
    return $self->{GET_REMOTE_PORT};
}

sub protocol {
    my $self = shift;
    if ($ENV{SERVER_PROTOCOL}) {
        $self->{PROTOCOL} = $ENV{SERVER_PROTOCOL};
    }  
    return $self->{PROTOCOL};        
}

sub header_only {
    my $self = shift;
    if ($self->{METHOD} eq 'HEAD') {
        return 1;    
    } else {
        return 0;
    }
}

sub modified_since {
    my $self = shift;
    my %months = ('Jan' => 0,'Feb' => 1,'Mar' => 2,'Apr' => 3,
                  'May' => 4,'Jun' => 5,'Jul' => 6,'Aug' => 7,
                  'Sep' => 8,'Oct' => 9,'Nov' => 10,'Dec' => 11
                 );    
    if ($ENV{HTTP_IF_MODIFIED_SINCE}) {
        $ENV{HTTP_IF_MODIFIED_SINCE} =~ 
            /^\S+,\s*(\d+)\s+(\S+)\s+(\d+)\s+(\d+):(\d+):(\d+)/ || return 0;
        $self->{MODIFIED_SINCE} = timegm($6,$5,$4,$1,$months{$2},$3 - 1900);            
    } else {
        return 0;
    }
    return $self->{MODIFIED_SINCE};
}

sub document_root {
    my $self = shift;
    if ($ENV{DOCUMENT_ROOT}) {
        $self->{DOCUMENT_ROOT} = $ENV{DOCUMENT_ROOT};
    }
    return $self->{DOCUMENT_ROOT};
}

sub script {
    my $self = shift;
    if ($ENV{SCRIPT_NAME}) {
        $self->{SCRIPT} = $ENV{SCRIPT_NAME};
    }
    return $self->{SCRIPT};   
}        

sub uri {
    my $self = shift;
    $self->{URI} = $ENV{REQUEST_URI};
    return $self->{URI};
}

sub the_request {
    my $self = shift;
    my $m = $self->method;
    my $u = $self->uri;
    my $p = $self->protocol;
    $self->{THE_REQUEST} = "$m $p $u";
    return $self->{THE_REQUEST};
}

sub query_string {
    my $self = shift;
    if ($ENV{QUERY_STRING}) {
        $self->{QUERY_STRING} = $ENV{QUERY_STRING};    
    }
    return $self->{QUERY_STRING};
}

sub args {
    my $self = shift;
    $self->parse_args(wantarray, $self->query_string);
}

sub parse_args {
    my $self = shift;
    my($wantarray,$string) = @_;
    return unless defined $string and $string;
    if(defined $wantarray and $wantarray) {
        return map { $self->unescape_url_info($_) } split /[=&]/, $string, -1;
    }
    return $string;
}

sub unescape_url_info {
    my $self = shift;
    my $s = shift;
    $s =~ s/\+/ /g;
    $s =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C",hex($1))/eg;
    return $s;
}

sub quote {
    my $self = shift;
    my $s = shift;
    if ($s =~ m/<\S+\@\S+>/) { # Catch email stuff
        $s =~ s,<,&lt\;,g;
        $s =~ s,>,\&gt\;,g;
    }
    $s =~ s,\n\s*\n,<br><br>\n,g;
    $s =~ s,\n,<br>\n,g;
    $s =~ s,\s\s,\&nbsp\;,g;
    
    return $s;
}

sub read_in {
    my $self = shift;
    my $l = shift;
    $l = $self->header_in('content_length') unless $l; 
    $self->timeout;
    read(STDIN,$self->{READ},$l);
    return $self->{READ};
}

sub header_in {
    my $self = shift;
    my $h = lc shift;
    my $k = undef;
    foreach $k (keys %ENV) {
        if ($k =~ /HTTP_ACCEPT_(\S+)/i) {
            $self->{HEADER_IN}{lc $1} = lc $ENV{$k};
        } elsif ($k =~ /HTTP_(\S+)/i) {
            $self->{HEADER_IN}{lc $1} = lc $ENV{$k};
        } elsif ($k =~ /(CONTENT_LENGTH)/i) {
            $self->{HEADER_IN}{lc $1} = lc $ENV{$k};
        } elsif ($k =~ /(CONTENT_TYPE)/i) {
            $self->{HEADER_IN}{lc $1} = lc $ENV{$k};
        }
    }
    if ($h) {
        return $self->{HEADER_IN}{$h} if $h ne '';
    }
    return %{$self->{HEADER_IN}};
}

sub header_out {
    my $self = shift;
    my ($k,$v) = @_;
    $self->{HEADER_OUT}{uc $k} = $v;
    return 1;    
}

sub send_http_header {
    my $self = shift;
    unless ($self->{HEADER_OUT}) {
        print "Content-Type: text/html\n\n";
        return 1;
    }
    foreach (keys %{$self->{HEADER_OUT}}) {
        print "$_: ${$self->{HEADER_OUT}}{$_}\n";   
    }
    print "Content-Type: text/html\n" if !${$self->{HEADER_OUT}}{'CONTENT-TYPE'};
    print "\n";
    return 1;
}

sub content_type {
    my $self = shift;
    my $c = shift;
    unless ($c) {
        $self->{HEADER_OUT}{'CONTENT-TYPE'} = 'text/html';
        return 1;
    }
    $self->{HEADER_OUT}{'CONTENT-TYPE'} = $c;
    return 1;
}

sub status {
    my $self = shift;
    my $s = shift;
    unless ($s || $s !~ /\d\d\d/) {
        $self->{HEADER_OUT}{STAUS} = 200;
        return 1;
    }
    $self->{HEADER_OUT}{STATUS} = $s;
    return 1;
}
    
package Server;
use strict;
sub new {
    my $that = shift;
    my $class = ref($that) || $that;
    my $self = {};
    $self->{SERVER_ADMIN} = undef;
    $self->{SERVER_HOSTNAME} = undef;
    bless ($self,$class);
    return $self;    
}

sub server_admin {
    my $self = shift;
    if ($ENV{SERVER_ADMIN}) {
        $self->{SERVER_ADMIN} = $ENV{SERVER_ADMIN};
    }
    return $self->{SERVER_ADMIN};
}

sub server_hostname {
    my $self = shift;
    if ($ENV{SERVER_NAME}) {
        $self->{SERVER_HOSTNAME} = $ENV{SERVER_NAME};
    }
    return $self->{SERVER_HOSTNAME};
}

package Error;
use strict;
sub new {
   my $that = shift;
   my $class = ref($that) || $that;
   my $self = {};
   $self->{REQUEST} = shift;
   $self->{WRITE} = undef;
   bless ($self,$class);
   return $self;
}

sub write {
   my $self = shift;
   my ($en,$es) = @_;
   my $r = $self->{REQUEST};
   my $ad = $r->server->server_admin;
   my $s = $r->server->server_hostname;
   $r->status($en);
   $r->content_type('text/html');
   $r->send_http_header;
   $r->status(200);

print <<EOF;
<HTML><HEAD><TITLE>Error $en</TITLE></HEAD><BODY BGCOLOR="WHITE">
<H1>Your request could not be served!</H1>
<B>Reason:</B> $es<P>
If you think this is serious you may send a report by following 
the link below. <br>
<a href="mailto:$ad?subject=Error $en, $es, $s">please submit this to me</a>
</BODY>
</HTML>
EOF
   exit();
}

package Form;
use strict;
sub new {
   my $that = shift;
   my $class = ref($that) || $that;
   my $self = {};
   $self->{REQUEST} = shift;
   $self->{GET} = [];
   bless ($self,$class);
   return $self;
}

sub get {
   my $self = shift;
   my ($k,$v,$buff) = '';
   my $r = $self->{REQUEST};
   my $ct = $r->header_in('content_type');
   if ($r->method eq "GET") {
      $buff = $r->args;
   } elsif ($r->method eq "POST") {
      if ($ct ne 'application/x-www-form-urlencoded') {
         $self->{ERROR} = "post not of type application/x-www-form-urlencoded";
         return 0;
      }
      $buff = $r->read_in;
   } 
   unless ($buff) {
     $self->{ERROR} = 'no form data'; 
     return 0;
   }
   my %n = ();
   foreach(split('&',$buff)) {
      ($k,$v) = split('=', $_);
      $v = $r->unescape_url_info($v);
      $k = $r->unescape_url_info($k);
      my $test = "$k:$v";
      $n{VAL} = $v;
      $n{NAME} = $k;
      push @{$self->{GET}} ,{%n};
   }
   return @{ $self->{GET}};
}

sub error {
    my $self = shift;
    return $self->{ERROR};   
}

package MultiForm;
use strict;
sub new {
   my $that = shift;
   my $class = ref($that) || $that;
   my $self = {};
   $self->{REQUEST} = shift;
   $self->{GET} = [];
   bless ($self,$class);
   return $self;
}

sub get {
   my $self = shift;
   my $le = shift;
   my ($buff,$h) = '';
   my %n = ();
   my $r = $self->{REQUEST};
   my $l = $r->header_in('content_length');
   my $ct = $r->header_in('content_type');

   if ($ct !~ /multipart\/form-data\;\s*boundary=(\S+)/) {
         push @{$self->{GET}} ,{-1, "post is not of type multipart"};
         return @{$self->{GET}};
   }
   
   my $b = $1;
   if ($le && $l > $le) {
      push @{$self->{GET}} ,{-1, "post is to large"};
      return @{$self->{GET}};
   }
   
   $buff = $r->read_in();

   my ($last,$f,$i) = 0;
   foreach(split(/\r\n/,$buff)) { # We need to set this back later
      $i++;
      if (/^--$b/i) {
         $h = 1;
         $f && push @{ $self->{GET}}, {%n};
         %n = ();
         $f = 1;
         next;
      } elsif (/^--$b--$/i) {
         push @{ $self->{GET}}, {%n};
         # We are at the end
         last;
      } elsif (
/^Content-Disposition:\s*form-data;\s*name=\"(.*)\";\s*filename=\"(.*)\"/
)     {
   ($n{NAME},$n{FILE}) = ($1,$2);
         next;
      } elsif (/^Content-Disposition:\s*form-data;\s*name=\"(.*)\"/) {
         $n{NAME} = $1;
         next;
      } elsif (/^Content-Type:\s*(\S+)\/(\S+)/ ) {
         ($n{TYPE},$n{STYPE}) = ($1,$2);
         next;
      }
      $h && /^$/ && ($h = 0,next); # body starts
      !$h || next;
      # get it back if the format is other then text
      if ($n{VAL}) {
         if ($n{TYPE} && $n{TYPE} eq 'text') {
            $n{VAL} = join "\n", $n{VAL},$_;
         } else {
            $n{VAL} = join "\r\n", $n{VAL},$_;
         }
      } else {
         $n{VAL} = $_;
      }
   }
   
   return @{ $self->{GET}};
}       
1;






