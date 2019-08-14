#!/usr/bin/perl

    use strict;
    use warnings;

    my @TARGET_SGS = ('^sg-service-.');



sub get_options
{
    if ( !exists($ARGV[0]) ) {
        print "usage: $0 [on|off]\n";
        exit(1);
    }
    my $on_off;
    if ( $ARGV[0] =~ /on|enable/i ) {
        $on_off = "on";
    }
    elsif ( $ARGV[0] =~ /off|disable/i ) {
        $on_off = "off";
    }
    else {
        die "set ON or OFF."
    }
    return $on_off;
}

sub get_enis
{
    my $aws_cmd = shift;
    my %enis;
    my $eni_id = '';
    open(P_CMD, "$aws_cmd describe-network-interfaces --query 'NetworkInterfaces[*]' |");
    while (<P_CMD>) {
        chomp;
        if ( /"NetworkInterfaceId": "([^"]+)"/ ) {
            $eni_id = $1;
        }
        if ( /"PrivateIpAddress": "([^"]+)"/ ) {
            if ( $eni_id ) {
                $enis{$eni_id} = $1;
                $eni_id = '';
            }
        }
    }
    return %enis;
}

sub get_sgs
{
    my $aws_cmd = shift;
    my %sgs;
    my $sg_name = '';
    open(P_CMD, "$aws_cmd describe-security-groups --query 'SecurityGroups[*]' |");
    while (<P_CMD>) {
        chomp;
        if ( /"GroupName": "([^"]+)"/ ) {
            $sg_name = $1;
        }
        if ( /"GroupId": "([^"]+)"/ ) {
            if ( $sg_name ) {
                $sgs{$sg_name} = $1;
                $sg_name = '';
            }
        }
    }
    return %sgs;
}

sub main
{
    my $on_off = &get_options;

    my $profile = exists($ARGV[1]) ? "--profile $ARGV[1]" : '';
    my $aws_cmd = "/usr/bin/aws $profile ec2";

    my %enis = &get_enis($aws_cmd);
    my %sgs = &get_sgs($aws_cmd);

    print "#!/bin/bash -x\n";

    my $date_str = `/usr/bin/date`;
    print "# generated at $date_str\n";

    print "# **** this scriptt is for " . uc($on_off) . " ****\n\n";

    print "# security group(s):\n";
    my @sg_ids;
    foreach my $sg_name (keys(%sgs)) {
        print "#   $sg_name: $sgs{$sg_name}";
        foreach my $target_sg (@TARGET_SGS) {
            if ( $sg_name =~ /$target_sg/ ) {
                print " (*)";
                if ($on_off eq 'on') {
                    push(@sg_ids, $sgs{$sg_name});
                }
            }
            else {
                push(@sg_ids, $sgs{$sg_name});
            }
        print "\n";
        }
    }
    print "\n";
    my $sg_ids_str = join(' ', @sg_ids);

    foreach my $eni_id (keys(%enis)) {
        my $full_cmd  = "$aws_cmd modify-network-interface-attribute --network-interface-id $eni_id --groups $sg_ids_str";
        print "# $eni_id ($enis{$eni_id}):\n";
        print "$full_cmd\n";
    }
}

&main();

