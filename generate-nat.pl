#!/usr/bin/perl

use warnings;
#use DBI;


# set public network and netmask
@publicnet=();
$publicnet[0]='xx.xx.xx.32/32';
$publicnet[1]='xx.237.176.159/32';
$publicnet[2]='xx.108.177.9/32';
$publicnet[3]='xx.108.178.240/32';
$publicnet[4]='xx.108.178.3/32';
$publicnet[5]='xx.108.178.4/32';
$publicnet[6]='xx.237.176.241/32';
$publicnet[7]='xx.237.176.239/32';
$publicnet[8]='xx.108.178.51/32';
$publicnet[9]='xx.237.176.66/32';
$publicnet[10]='xx.237.176.206/32';
$publicnet[11]='xx.237.176.201/32';
$publicnet[12]='xx.237.176.199/32';
$publicnet[13]='xx.237.176.244/32';
$publicnet[14]='xx.237.176.25/32';
$publicnet[15]='xx.108.177.5/32';
$publicnet[16]='xx.108.177.4/32';

#$publicnetsize = scalar(@publicnet);

# set private network and netmask
###ppp
$privatenet='10.130.0.0/22'; 

# set private pptp gateway IP
$gwip = '10.130.0.1';

# set output file
$output = '/scripts/nat-firewall.sh';



### DON'T TOUCH BELOW UNLESS YOU KNOW WHAT YOU ARE DOING ###


$answer = 'y';

#if(-e $output) {
#	print "File $output already exists. Shoud i replace it? (y/n): ";
#	$answer = <STDIN>;
#	chomp $answer;
#	print "\n";
#}

if($answer ne 'y') {
	print "Program stopped\n";
	exit;
}

# getting ip addresses ranges and generating output file

@publicips = ();

foreach $tmpnet (@publicnet) {
	chomp $tmpnet;

	($publicnetwork, $publicnetmask) = split(/\//, $tmpnet);

	@tmppublicips = &prepareIps($publicnetwork, $publicnetmask, 1);
	@publicips = &array_merge(\@publicips, \@tmppublicips);
#        print @publicips; print "\n"; exit;

}
#        print join(@publicips, "\n"); print "\n"; exit;

($privatenetwork, $privatenetmask) = split(/\//, $privatenet);

@privateips = &prepareIps($privatenetwork, $privatenetmask, 0);


# open vpn network config
#($openvpnprivatenetwork, $openvpnprivatenetmask) = split(/\//, $openvpnnet);

#@openvpnprivateips = &prepareIps($openvpnprivatenetwork, $openvpnprivatenetmask, 1);

#@privateips = &array_merge(\@privateips, \@openvpnprivateips);

# end of openvpn



$publicipsize = scalar @publicips;


open(OF, ">", $output) or die $!;

print OF "#!/bin/bash\n";
print OF "# automatically generated script for randomly nat of public ips\n";
print OF "\n";

print OF '# Declare internet ip & i-face' . "\n";
print OF 'INET_IFACE="eth0"' . "\n";
print OF "\n";
print OF '# Path to iptables executable' . "\n";
print OF 'IPTABLES="/sbin/iptables"' . "\n\n";

foreach $ip (@privateips) {
	chomp $ip;
	if($gwip eq $ip) {
		next;
	}
	if(defined($staticips{$ip}) && $staticips{$ip} ne '') {
		next; # skipping static ip
	}
	$rnd = int(rand($publicipsize));
	$publicip = $publicips[$rnd];
	print OF '$IPTABLES -t nat -A POSTROUTING -p all -o $INET_IFACE -s ' . $ip . ' -j SNAT --to-source ' . $publicip . "\n";
}

print OF "\n# generate SNAT for static ips from table ips\n";
foreach $s (keys %staticips) {
	chomp $s;
	print OF '$IPTABLES -t nat -A POSTROUTING -p all -o $INET_IFACE -s ' . $s . ' -j SNAT --to-source ' . $staticips{$s} . "\n";
}

close OF;

#print "@publicips";
#print "\n\n\n";
#print join("\n", @privateips);
#print "\n";

sub prepareIps($$$) {
	$network = shift;
	$netmask = shift;
	$skipfirst = shift;

	@pips = ();

	if($netmask eq '32') {
		push(@pips, $network);
		return @pips;		
	}

	@ips = &findFirstUsableIp($network, $netmask);

	$max = $ips[4];

	$first = $ips[0];
	$second = $ips[1];
	$third = $ips[2];
	$forth = $ips[3];

	if($skipfirst != 1) {
		push(@pips, $first . '.' . $second . '.' . $third . '.' . $forth);
	}

	$newforth = $forth;
	$newthird = $third;
	$newsecond = $second;
	$newfirst = $first;
	for($i=1;$i<$max;$i++) {
		$newforth = $newforth+1;
		$newthird = $newthird;
		$newsecond = $newsecond;
		$newfirst = $newfirst;
		if($newforth == 255) {
			$newforth = 1;
			$newthird = $newthird + 1;
			$i = $i+2;
		}
		if($newthird == 255) {
			$newthird = 1;
			$newsecond = $newsecond + 1;
		}
		if($newsecond == 255) {
			$newsecond = 1;
			$newfirst = $newfirst + 1;
		}
		push(@pips, $newfirst . '.' . $newsecond . '.' . $newthird . '.' . $newforth);
	}

	return @pips;
}

sub findFirstUsableIp($$) {

	$ip = shift;
	$mask = shift;

	$wildcard = '';
	for($i=0;$i<(32-$mask);$i++) {
		$wildcard .= '1';
	}

	$netcard = '';
        for($i=0;$i<(32-$mask);$i++) {
                $netcard .= '0';
        }


	($first, $second, $third, $forth) = split(/\./, $ip);

	$binform = &dec2bin($first) . &dec2bin($second) . &dec2bin($third) . &dec2bin($forth);
	
	$netip = substr($binform,0,$mask) . $netcard;

	$broadcast = substr($binform,0,$mask) . $wildcard;

	$firstUsable = substr($netip, 0, 31) . '1';
	$lastUsable = substr($broadcast, 0, 31) . '0';

	$totalIpsBin = substr($lastUsable, $mask);
	$totalIps = &bin2dec($totalIpsBin);
	@result = (&bin2dec(substr($firstUsable, 0, 8)), &bin2dec(substr($firstUsable, 8, 8)), &bin2dec(substr($firstUsable, 16, 8)), 
&bin2dec(substr($firstUsable, 24, 8)), $totalIps);
	return @result;
}

sub bin2dec($) {
	$result = unpack("N", pack("B32", substr("0" x 32 . shift, -32)));
	return $result;
}

sub dec2bin($) {
	my $str = unpack("B32", pack("N", shift));
	$str =~ s/^0+(?=\d)//;   # otherwise you'll get leading zeros
        if(length($str) < 8) {
		$max = 8 - length($str);
                for($i=0;$i<$max;$i++) {
                        $str = '0' . $str;
                }
        }

	return $str;
}

sub array_merge() {
	$array1 = shift;
	$array2 = shift;
	
	@newarray = @$array1;

	foreach $s (@$array2) {
		chomp $s;
		push(@newarray, $s);
	}
	return @newarray;
}
