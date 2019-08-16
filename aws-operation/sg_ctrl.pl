#!/usr/bin/perl

    use strict;
    use warnings;


    my $FILTER = '';


sub get_sg_name_from_id
{
    my $sg_id = shift;
    my $sg_name = `aws ec2 describe-security-groups --group-id $sg_id $FILTER --query 'SecurityGroups[].[GroupName]' --output text`;
    chomp($sg_name);
    return $sg_name;
}

sub get_sg_id_from_name
{
    my $sg_name = shift;
    my $sg_id = `aws ec2 describe-security-groups --group-name $sg_name $FILTER --query 'SecurityGroups[].[GroupId]' --output text`;
    chomp($sg_id);
    return $sg_id;
}

sub run_cli
{
    my $subcmd = shift;
    my $query = shift;
    my @result;
    open(P_CMD, "aws ec2 $subcmd $FILTER --query '$query' --output text |");
    while (<P_CMD>) {
        chomp;
        push(@result, $_);
    }
    close(P_CMD);
    return @result;
}

sub get_security_groups
{
    my %sgs;
    my @result = &run_cli(
        'describe-security-groups',
        'SecurityGroups[].[GroupId, GroupName]'
    );
    foreach (@result) {
        if ( /^(sg-\w+)\s+(.+)$/ ) {
            $sgs{$2} = $1;
        }
    }
    return %sgs;
}

sub get_instances
{
    my %instances;
    my @result = &run_cli(
        'describe-instances',
        'Reservations[].Instances[].[InstanceId, Tags[?Key==`Name`].Value|[0]]'
    );
    foreach (@result) {
        if ( /^(i-\w+)\s+(.+)$/ ) {
            $instances{$1} = $2;
        }
    }
    return %instances;
}

sub get_network_interfaces
{
    my %enis;
    my $eni;
    my @result = &run_cli(
        'describe-network-interfaces',
        'NetworkInterfaces[].[NetworkInterfaceId, PrivateIpAddress, Attachment.InstanceId, Groups]'
    );
    foreach (@result) {
        if ( /^(eni-\w+)\s+([\d\.]+)\s+(i-\w+)$/ ) {
            $eni = $1;
            $enis{$eni}{ipaddr} = $2;
            $enis{$eni}{instance_id} = $3;
        }
        elsif ( /^(eni-\w+)\s+([\d\.]+)\s+None$/ ) {
            $eni = $1;
            $enis{$eni}{ipaddr} = $2;
            $enis{$eni}{instance_id} = '';
        }
        elsif ( /^(sg-\w+)\s+(.+)$/ ) {
            push( @{$enis{$eni}{sg}}, $2 );
        }
    }
    return %enis;
}

sub show_current_status
{
    my %instances = &get_instances();
    my %enis = &get_network_interfaces();

    foreach my $eni ( sort keys %enis ) {
        my $instance_info = '(unattached)';
        if ( exists($instances{$enis{$eni}{instance_id}}) && $instances{$enis{$eni}{instance_id}} ) {
            my $instance_name = $instances{$enis{$eni}{instance_id}};
            $instance_info = "$enis{$eni}{instance_id}($instance_name)";
        }
        my $ipaddr = $enis{$eni}{ipaddr};
        my $sgs = '';
        if ( exists($enis{$eni}{sg}) &&  @{$enis{$eni}{sg}} ) {
            $sgs = join(' ', @{$enis{$eni}{sg}});
        }
        print "$eni $ipaddr $instance_info: $sgs\n";
    }
}

sub make_recover_script
{
    my $vpc_id = shift;
    my %instances = &get_instances();
    my %enis = &get_network_interfaces();
    my %sgs = &get_security_groups();

    print "#!/bin/bash -x\n\n";

    print "# generated information:\n";
    print "#   date: " . `date`;
    print "#   uname: " . `uname -snrv`;
    print "#   id: " . `id`;
    print "\n";

    my $vpc_info = $vpc_id ? "at $vpc_id" : 'at all vpcs';
    print "# all security groups $vpc_info:\n";
    foreach my $sg_name (sort(keys(%sgs))) {
        print "#   $sgs{$sg_name}: $sg_name\n";
    }
    print "\n";

    if ( $ENV{AWS_DEFAULT_PROFILE} ) {
        print "export AWS_DEFAULT_PROFILE=$ENV{AWS_DEFAULT_PROFILE}\n\n";
    }

    foreach my $eni (sort(keys(%enis))) {
        my $instance_info = '(unattached)';
        if ( exists($instances{$enis{$eni}{instance_id}}) && $instances{$enis{$eni}{instance_id}} ) {
            my $instance_name = $instances{$enis{$eni}{instance_id}};
            $instance_info = "$enis{$eni}{instance_id}($instance_name)";
        }
        my $ipaddr = $enis{$eni}{ipaddr};
        my @sg_ids;
        foreach my $sg_name ( @{$enis{$eni}{sg}} ) {
            push( @sg_ids, $sgs{$sg_name} );
        }
        my $sg_names = join(' ', @{$enis{$eni}{sg}});
        my $sg_ids = join(' ', @sg_ids);
        next if ( ! $sg_names );
        print "# $eni $ipaddr $instance_info: $sg_names\n";
        print "/usr/bin/aws ec2 modify-network-interface-attribute $FILTER --network-interface-id $eni --groups $sg_ids\n";
    }

}

sub parse_options
{
    my $cmd;
    my $vpc_id;
    foreach my $args ( @ARGV ) {
        if ( ! $cmd ) {
            $cmd = $args;
        }
        elsif ( $args =~ /^vpc-/ ) {
            $vpc_id = $args;
        }
    }

    if ( ! $cmd ) {
        $cmd = 'show';
    }
    if ( $vpc_id ) {
        $FILTER = "--filter \"Name='vpc-id',Values='$vpc_id'\"";
    }
    return ($cmd, $vpc_id);
}


my ($cmd, $vpc_id) = &parse_options();
if ( $cmd =~ /show/i ) {
    &show_current_status();
}
elsif ( $cmd =~ /save|backup/i ) {
    &make_recover_script($vpc_id);
}
elsif ( $cmd =~ /add|on|set/i ) {

}
elsif ( $cmd =~ /delete|remove|off|unset/i ) {

}
