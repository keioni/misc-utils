#!/usr/bin/perl

    use strict;
    use warnings;

    # sg-ctrl show vpc-xxxxxxxxxxxxxxxxxx
    # sg-ctrl add proxy vpc-xxxxxxxxxxxxxxxxxxxxx
    # sg-ctrl remove proxy vpc-xxxxxxxxxxxxxxxxxxxxxx


my $PROFILE = '';
my $FILTER = '';


# sub get_sg_name_from_id
# {
#     my $sg_id = shift;
#     my $sg_name = `aws $PROFILE ec2 describe-security-groups --group-id $sg_id $VPC_ID --query 'SecurityGroups[].[GroupName]' --output text`;
#     chomp($sg_name);
#     return $sg_name;
# }

# sub get_sg_id_from_name
# {
#     my $sg_name = shift;
#     my $sg_id = `aws $PROFILE ec2 describe-security-groups --group-name $sg_name $VPC_ID --query 'SecurityGroups[].[GroupId]' --output text`;
#     chomp($sg_id);
#     return $sg_id;
# }


sub get_security_groups
{
    my %sgs;
    open(P_CMD, "aws $PROFILE ec2 describe-security-groups $FILTER --query 'SecurityGroups[].[GroupId, GroupName]' --output text |");
    while (<P_CMD>) {
        chomp;
        if ( /^(sg-\w+)\s+([\w_-]+)$/ ) {
            $sgs{$1} = $2;
        }
    }
    close(P_CMD);
    return %sgs;
}

sub get_instances
{
    my %instances;
    open(P_CMD, "aws $PROFILE ec2 describe-instances $FILTER --query 'Reservations[].Instances[].[InstanceId, Tags[?Key==`Name`].Value|[0]]' --output text |");
    while (<P_CMD>) {
        chomp;
        if ( /^(i-\w+)\s+([\w_-]+)$/ ) {
            $instances{$1} = $2;
        }
    }
    close(P_CMD);
    return %instances;
}

sub get_network_interfaces
{
    my %enis;
    my $eni;
    open(P_CMD, "aws $PROFILE ec2 describe-network-interfaces $FILTER --query 'NetworkInterfaces[].[NetworkInterfaceId, PrivateIpAddress, Attachment.InstanceId, Groups]' --output text |");
    while (<P_CMD>) {
        chomp;
        if ( /^(eni-\w+)\s+([\d\.]+)\s+(i-\w+)$/ ) {
            $eni = $1;
            $enis{$eni}{ipaddr} = $2;
            $enis{$eni}{instance_id} = $3;
        }
        if ( /^(sg-\w+)\s+(\w+)$/ ) {
            push( @{$enis{$eni}{sg}}, $2 );
        }
    }
    close(P_CMD);
    return %enis;
}

sub show_current_status
{
    my %instances = &get_instances();
    my %enis = &get_network_interfaces();

    foreach my $eni ( sort keys %enis ) {
        my $instance_name = $instances{$enis{$eni}{instance_id}};
        my $ipaddr = $enis{$eni}{ipaddr};
        my $sgs = join(' ', @{$enis{$eni}{sg}});
        print "$eni $ipaddr $enis{$eni}{instance_id}($instance_name): $sgs\n";
    }
}

if ( @ARGV ) {
    my $cmd = shift;
    if ( $cmd =~ /show/i ) {
        my $vpc_id = shift;
        if ( $vpc_id && $vpc_id =~ /^vpc-/ ) {
            $FILTER = "--filter \"Name='vpc-id',Values='$vpc_id'\"";
        }
        &show_current_status();
    }
}
