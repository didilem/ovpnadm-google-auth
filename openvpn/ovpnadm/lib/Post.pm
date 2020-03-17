# Routines for inserting content into the News Database
# This runs only within the environment of THTML©
# Routine to access content from post method 
package Post;
use FileHandle;
sub new {
    my $that = shift;
    my @data = @_;
    my $class = ref($that) || $that;
    my $self = {};
    $self->{NAMES} = [];
    $self->{VAL} = undef;
    $self->{TYPE} = undef;
    $self->{STYPE} = undef;
    $self->{Error} = FieldError->new;
    $self->{Date} = Date->new;
    $self->{Doc} = Doc->new;
    $self->{Email} = Email->new;
    $self->{Card} = Card->new;
    $self->{Num} = Num->new;
    
    # fill the form data
    my ($t, $has,$i) = '';
    my @name = ();
    for $i (0 .. $#data) {
        push @name, $data[$i]{NAME};
        #$data[$i]{VAL} ne '' && ($self->{VAL}{$i} = $data[$i]{VAL}) || ($self->{VAL}{$i} = '');
        $self->{VAL}{$i} = $data[$i]{VAL};
        $data[$i]{TYPE} && ($self->{TYPE}{$i} = $data[$i]{TYPE}) || ($self->{TYPE}{$i} = '');
        $data[$i]{STYPE} && ($self->{STYPE}{$i} = $data[$i]{STYPE}) || ($self->{STYPE}{$i} = '');
    }
    $self->{NAMES} = \@name;
    bless $self,$class;
    return $self;
}

sub names {
    my $self = shift;
    return @{$self->{NAMES}};   
}

sub val {
    my $self = shift;
    my $key = shift;
    return $self->{VAL}{$key};
}

sub type {
    my $self = shift;
    my $key = shift;
    return $self->{TYPE}{$key};
}

sub stype {
    my $self = shift;
    my $key = shift;
    return $self->{STYPE}{$key};
}

sub error {
    $self = shift;
    return $self->{Error};    
}

sub date {
    $self = shift;
    return $self->{Date};
}

sub doc {
    $self = shift;
    my ($f,$i,$s) = @_;
    $self->{Doc}{FORM} = $f;
    $self->{Doc}{IMAGE} = $i;
    $self->{Doc}{SIZE} = $s;
    return $self->{Doc};
}

sub email {
    $self = shift;
    return $self->{Email};
}

sub card {
    $self = shift;
    return $self->{Card};
}

sub num {
    $self = shift;
    return $self->{Num};
}

package FieldError;
sub new {
    my $that = shift;
    my $class = ref($that) || $that;
    my $self = {};
    $self->{RET} = undef;
    bless $self,$that;
    return $self;
}

sub val {
    my $self = shift;
    my ($p,$s,@err) = @_;
    foreach (@err) {
        $self->{RET} .= "$p$_$s"; 
    }
    return $self->{RET};
}

sub bye {
    my $self = shift;
    return $self->{RET};
}

package Date;
sub new {
    my $that = shift;
    my $class = ref($that) || $that;
    my $self = {};
    $self->{DATE} = undef;
    bless $self,$that;
    return $self;
}

sub check {
    my $self = shift;
    my $date = shift;
    # Check the month an set possible days
    my %months = ('01','1','02','3','03','1',
                  '04','2','05','1','06','2',
                  '07','1','08','1','09','2',
                  '10','1','11','2','12','1');

    if ($date =~ /(\d{4})(\d{2})(\d{2})/) {
        my ($y,$m,$d) = ($1,$2,$3);
        my @days;
        my ($yok,$mok,$dok);
        $y >= 1997 && ($yok = 1);
        foreach (keys %months) {
            if ($_ == $m) {
                $mok = 1;
                $months{$m} == 1 && (@days = ('01' .. '31')); 
                $months{$m} == 2 && (@days = ('01' .. '30'));
                $months{$m} == 3 && (@days = ('01' .. '29'));
            }
        }
        foreach(@days) { /$d/ && ($dok = 1);}
        $yok && $mok && $dok || ($date = 0);
    } elsif ($date eq 'heute') {
        my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
        my @month = ('01' .. '12'); 
        my @days = ('00' .. '31');
        $date = 1900 + $year  . $month[$mon] . $days[$mday];
    } else {
        $date = 0;
    }
    $self->{DATE} = $date;
    return $self->{DATE};    
}

package Doc;
sub new {
    my $that = shift;
    my $class = ref($that) || $that;
    my ($f,$i,$s) = @_;
    my $self = {};
    $self->{TYPE} = undef;
    $self->{FORM} = $f;
    $self->{IMAGE} = $i;
    $self->{SIZE} = $s;
    bless $self,$that;
    return $self;
}

sub size {
    my $self = shift;
    my $size = $self->{SIZE};
    my $f = $self->{FORM};
    my $i = $self->{IMAGE};
    if ($size) {
        if (length($f->val($i)) > $size) {
            return 0;
        }
    }
    return 1;
}

sub type {
    my $self = shift;
    my $t = shift; # what should we get
    my $f = $self->{FORM};
    my $i = $self->{IMAGE};
    my %type = (
                'text',{'html',1,'plain',1},
                'image',{'jpeg',1,'gif',1}
                );
    if (!$f->type($i) && !$f->stype($i)) {
        # Now we test the file with 'file'
        $self->get_type("$t") || return 0;   
    } elsif (!$type{$f->type($i)}) {
        $self->get_type($t) || return 0;
    } elsif (!$type{$f->type($i)}{$f->stype($i)}) {
        $self->get_type($t) || return 0;  ;
            
    }
    return 1;
}

sub get_type {
    my $self = shift;
    my $t = shift;
    my $f = $self->{FORM};
    my $i = $self->{IMAGE};
    my %type = (
                'text',{'html',1,'plain',1},
                'image',{'jpeg',1,'gif',1}
                );
    my $stamp = '/tmp/thtml' . rand time;
    my $fh = new FileHandle "> $stamp";
    if ($f->val($i)) {
        print $fh $f->val($i);
        $fh->close;
    }
    my $test = lc `file $stamp`;
    chop($test);
    $test =~ s/^\S+:\s(\S+)\s*.*$/$1/;
    if ($type{$t}{$test}) {
        $self->{TYPE} = $t;
        $self->{STYPE} = $test;
        unlink $stamp;
        return 1;
          
    } 
    $self->{TYPE} = $test;
    unlink $stamp;
    return 0;
}

sub real_type {
    $self = shift;
    return $self->{TYPE};
}

package Email;
sub new {
    my $that = shift;
    my $class = ref($that) || $that;
    my $self = {};
    $self->{Email} = undef;
    bless $self,$that;
    return $self;
}

sub check {
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

package Card;
sub new {
    my $that = shift;
    my $class = ref($that) || $that;
    my $self = {};
    $self->{Card} = undef;
    bless $self,$that;
    return $self;
}

sub check_master {
	my $self = shift;
	my $n = join('', split(/\s/, shift));
	unless ($n =~ m,^5[1-5],) {
		# The card does not match the requierd two start digits
		return 0;
	}
	unless (length($n) == 16) {
		# Mastercard has always a lenght of 16 digits
		return 0;
	}
	unless ($self->mod_10($n)) {
		# is the card number vaild? check it against 'mod 10'
		return 0;
	}
	$self->{Card} = 'valid';
}

sub check_visa {
	my $self = shift;
	my $n = join('', split(/\s/, shift));
	unless ($n =~ m,^4,) {
		# The card does not match the requierd two start digit
		return 0;
	}
	unless (length($n) == 16 || length($n) == 13) {
		# Visa has either 16 or 13 digits
		return 0;
	}
	unless ($self->mod_10($n)) {
		# is the card number vaild? check against 'mod 10'
		return 0;
	}
	$self->{Card} = 'valid';
}

sub check_amex {
	my $self = shift;
	my $n = join('', split(/\s/, shift));
	unless ($n =~ m,^3[47],) {
		# The card does not match the requierd two start digit
		return 0;
	}
	unless (length($n) == 15) {
		return 0;
	}
	unless ($self->mod_10($n)) {
		# is the card number vaild? check against 'mod 10'
		return 0;
	}
	$self->{Card} = 'valid';
}

sub check_myone {
	my $self = shift;
	my $n = join('', split(/\s/, shift));
	unless ($n =~ m,^600452020,) {
		# The card does not match the requierd start digits
		return 0;
	}
	unless (length($n) == 19) {
		return 0;
	}
	unless ($self->mod_10($n)) {
		# is the card number vaild? check against 'mod 10'
		return 0;
	}
	$self->{Card} = 'valid';
}

sub mod_10 {
	my $self = shift;
	my $n = shift;
	my $val = 0;
	my $sum = 0;
	my $v = 1;
	for (my $i = (length $n) -1; $i >= 0; $i--) {
		$val = (substr $n, $i, 1) * $v;
		$val = $val - 9 if ($val > 9); 
		$sum = $sum + $val;
		if ($v == 1) {
			$v = 2;
		} else {
			$v = 1;
		}
	}
	$sum = $sum % 10;
	if ($sum != 0) {
		return 0;
	} else {
		return 1;
	}
}

sub check_expire {
    my $self = shift;
    my $date = my $n = join('', split(/\s/, shift)); # remove spaces
    unless ($date =~ m,^(\d\d)/(\d\d)$,) {
	# the supplied date matches not our requierment
        return 0;
    }
    my ($m,$y) = ($1,$2);
    my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
    # check the year -> stupid 2 digit problem
    # Well this breaks in 50 years but it won't (04.04.99)
    # run that long I assume.....
    if ($y < 99 && $y <= 49) {
	$y = 2000 + $y;
    } else {
	$y = 1900 + $y;
    }
    if ($y < $year + 1900) {
	return 0;
    } elsif ($y == $year + 1900) {
	# check the month, too
	if ($m < $mon + 1) { return 0; # It's an array
	    return 0;
	}
    } 
 
    # Check the month anyway
    if ($m =~ m,^0,) {
	unless ($m =~ m,^[0][0-9],) {
          return 0;
        }
    } elsif  ($m =~ m,^1,) {
       unless  ($m =~ m,^[1][0-2],) {      
          return 0;
       }
    } else {
       return 0;
    } 
    return 1; 
}

package Num;
sub new {
    my $that = shift;
    my $class = ref($that) || $that;
    my $self = {};
    $self->{Num} = undef;
    bless $self,$that;
    return $self;
}

# check if the supplied field has numerical value
sub check {
    my $self = shift;
    my $n = shift;
    return 1 if ($n =~ /^[\d\s]+$/);
    return 0;
}
1;






