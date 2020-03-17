package OVPNADM::config;

use strict; use warnings;
use parent 'Exporter';

our @EXPORT = qw($SSL $DBH $AUTHER $SERVER);

our $SSL = {
   'country' => 'UK',
   'state' => 'Cornwall',
   'loc' => 'Redruth',
   'orga' => 'UKRD Group Limited',
   'orgaunit' => 'OVPN',
   };

our $DBH = {
   'db' => 'ovpnadm',
   'user' => 'ovpnadm',
   'pass' => 'dji&eref!',
   'host' => '127.0.0.1'
   };

our $AUTHER = {
   'label' => 'UKRD_Group_Limited',
   'qr-size' => '200',
};

our $SERVER = {
    'remote' => 'my server',
};

1;
