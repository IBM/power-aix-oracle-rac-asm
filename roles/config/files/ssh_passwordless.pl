#!/usr/bin/perl

# Copyright (c) IBM Corporation 2021

# This script runs on Ansible controller which creates/updates known_hosts
# and authorized_keys (assuming users' public keys are in place) for root
# and another specified user. It should only be run once, not per host. 
# Provision is made for two public networks: the "public" for say
# admin/management and "oracle public" for Oracle RAC clients access. 
# The term 'hosts' refers to "public" and 'nodes' refers to "oracle public".
# If "public" isn't specified, 'hosts' is treated as 'nodes'.
# 
# The order of the hosts and nodes must match the same system. It is expected,
# the Ansible task generates the hosts and nodes from config.networks,
# hence the orders and mapping between hosts and nodes are maintained.
#
# Idempotent: yes
#
# sub           type   array             reference  file                    params
#get_src_keys   host   host_keys         src_keys   ssh_host_ecdsa_key.pub  ("host", "root")
#               host   N/A               N/A        N/A                     ("host", "oracle")
#gen_dest_keys  host   root_known_hosts  dest_keys  ~/.ssh/known_hosts      ("host", "root")
#               host   user_known_hosts  dest_keys  ~/.ssh/known_hosts      ("host", "oracle")

#get_src_keys   user   root_rsa_pub      src_keys   ~/.ssh/id_ras.pub       ("user", "root")
#               user   user_rsa_pub      src_keys   ~/.ssh/id_ras.pub       ("host", "oracle")
#gen_dest_keys  user   root_auth_keys    dest_keys  ~/.ssh/authorized_keys  ("user", "root")
#               user   user_auth_keys    dest_keys  ~/.ssh/authorized_keys  ("host", "oracle")

use Getopt::Std;
$debug = 0;

sub usage() {
  print "Usage: ssh_passwordless.pl \
      [-h <\"host ...\">] [-d \"<domain\">] -u <user> -n <\"node ...\"> -i \"<ip> ...\"\n";
  exit 1;
}

if (!getopts('d:h:i:n:u:D')) {
  print "ERROR: getopts() failed: $!\n";
  usage;
}

$hosts_str  = $opt_h if defined $opt_h;
$nodes_str  = $opt_n if defined $opt_n;
$ips_str    = $opt_i if defined $opt_i;
$user       = $opt_u if defined $opt_u;
$domain     = $opt_d if defined $opt_d;
$debug      = 1      if defined $opt_D;

if ($nodes_str eq "" or $user eq "" or $ips_str eq "") {
  usage;
}

@ips   = split(/\s+/, $ips_str);
@nodes = split(/\s+/, $nodes_str);
@hosts = ($hosts_str eq "") ? @nodes : split(/\s+/, $hosts_str);

if ($user ne "root") {
  $cmd = "ssh -T root\@$hosts[0] grep ${user}: /etc/passwd |awk -F: \"{ print \\\$6 }\"";
  $user_home = `$cmd`;
  die "ERROR: user $user not found." if $user_home eq "";
  chomp $user_home;

  $cmd = "ssh -T root\@$hosts[0] groups $user | awk \"{ print \\\$3 }\"";
  $user_group = `$cmd`;
  die "ERROR: group $group not found." if $user_group eq "";
  chomp $user_group;
}

@host_keys;
@root_known_hosts;
@user_known_hosts;
@root_rsa_pub;
@user_rsa_pub;
@root_auth_keys;
@user_auth_keys;
@curr_keys;

sub get_src_keys {
  ($type, $_user) = (@_);
  print "DEBUG: ", __LINE__, " get_src_keys(): type=$type, _user=$user\n" if $debug;
  die "ERROR: get_src_keys(): type parameter is blank.\n" if "$type" eq "";
  die "ERROR: get_src_keys(): user parameter is blank.\n" if "$_user" eq "";

  if ($type eq "host") {
    $key_file = "/etc/ssh/ssh_host_ecdsa_key.pub";
    $src_keys_ref = \@host_keys;
  } else {
    $home = ($_user eq "root") ? "/" : "$user_home";
    print "DEBUG: ", __LINE__, " get_src_keys(): home=$home\n" if $debug; 
    $key_file = "$home/.ssh/id_rsa.pub";
    print "DEBUG: ", __LINE__, " get_src_keys(): key_file=$key_file\n" if $debug;
    $src_keys_ref = ($_user eq "root") ? \@root_rsa_pub : \@user_rsa_pub;
  }

  for $h (@hosts) {
     # In Power/VS, this file is missing, so generate it
     if ("$key_file" eq "/etc/ssh/ssh_host_ecdsa_key.pub") {
       $status = `ssh root\@$h "[[ -f $key_file ]] && echo "Exists" || echo "not found""`; chomp $status;
       if ($status =~ "not found") {
         `ssh root\@$h '/usr/bin/ssh-keyscan -H $h 2>/dev/null | \
                       grep ssh-rsa | \
                       awk \"{ print \\\$2, \\\$3 }\" > /etc/ssh/ssh_host_ecdsa_key.pub'`;
       }
       if ( -z "$key_file" ) {
	  `ssh root\@$h '/usr/bin/ssh-keyscan -H $h 2>/dev/null | \
                       grep ssh-rsa | \
                       awk \"{ print \\\$2, \\\$3 }\" > /etc/ssh/ssh_host_ecdsa_key.pub'`;
       }
       if ( -z "$key_file" ) {
	  print "ERROR: Failed to create file  $key_file on $h : size of file is zero \n";
	  print "Delete the file $key_file and rerun the config role \n";
	  exit 1;
       }
     }

    $key = `ssh root\@$h cat $key_file`;
    chomp $key;
    if ($key =~ /cannot open/) {
      print "ERROR: get_keys(): Failed to open $key_file on $h.\n";
      exit 1;
    }
    push(@$src_keys_ref, "$key");  
  }
  print "DEBUG: ", __LINE__, " get_src_keys(): num of src_keys=", scalar @$src_keys_ref, "\n" if $debug;
}

sub gen_dest_keys {
  ($type, $_user, $_dest_user) = (@_);
  print "DEBUG: ", __LINE__, " gen_dest_keys(): type=$type, _user=$user, _dest_user=$_dest_user\n" if $debug;
  die "ERROR: gen_dest_keys(): type parameter is blank.\n" if "$type" eq "";
  die "ERROR: gen_dest_keys(): user parameter is blank.\n" if "$_user" eq "";

  $home = ($_user eq "root") ? "/" : "$user_home";
  print "DEBUG: ", __LINE__, " gen_dest_keys(): home=$home\n" if $debug; 
  if ($type eq "host") {
    $src_keys_ref   = \@host_keys;
    $dest_keys_ref  = ($_user eq "root") ? \@root_known_hosts
                                         : \@user_known_hosts;
    $file           = "$home/.ssh/known_hosts";
  } else {
    $src_keys_ref   = ($_user eq "root") ? \@root_rsa_pub
                                         : \@user_rsa_pub;
    if ($_dest_user eq "root") {
      $dest_keys_ref  = \@root_auth_keys;
      $file           = "/.ssh/authorized_keys";
    } elsif ($_dest_user ne "") {
      $dest_keys_ref  = \@user_known_hosts;
      $file           = "$user_home/.ssh/authorized_keys";
    } else {
      $dest_keys_ref  = ($_user eq "root") ? \@root_auth_keys
                                           : \@user_auth_keys;
      $file           = "$home/.ssh/authorized_keys";
    }
    print "DEBUG: ", __LINE__, " gen_dest_keys(): file=$file\n" if $debug;
  }

  for $h (@hosts) {
    @$dest_keys_ref = ();
    $j = 0;

    # Get source entries
    for $n (@nodes) {
      $content1 = ($type eq "host") ? "$n,$ips[$j] @$src_keys_ref[$j]"
                                    : "@$src_keys_ref[$j]$_user\@$n";
      push(@$dest_keys_ref, "$content1");
      if ("$domain" ne "") {
        $content2 = ($type eq "host") ? "${n}.${domain} @$src_keys_ref[$j]"
                                      : "@$src_keys_ref[$j]$_user\@${n}.${domain}";
        push(@$dest_keys_ref, "$content2");
      }
      $j++;
    } # for $n
    print "DEBUG: ", __LINE__, " gen_dest_keys(): num of dest_keys_ref=", scalar @$dest_keys_ref, "\n" if $debug;

    # Process dest entries
    $output = `ssh root\@$h cat $file 2>&1`;
    if ($output =~ /cannot open/) {
      print "DEBUG: ", __LINE__, " gen_dest_keys(): $file does not exist.\n" if $debug;
      # known_hosts/authorized_keys file doesn't exist, construct entries and write them out
      $items = join("\n", @$dest_keys_ref);
      open($fh, "| ssh -T root\@$h \"cat > $file\"") or
        die "ERROR: gen_dest_keys(): Failed to connect to $h for creating $file.\n";
      print $fh "$items\n";
      close $fh;
      system("ssh root\@$h chown ${_user}:$user_group $file") if ($_user ne "root");
      print "$file changed on $h.\n";
    } else {
      print "DEBUG: ", __LINE__, " gen_dest_keys(): $file exists.\n" if $debug;
      # Add keys to dest file if they don't already exist
      @curr_keys = ();
      @missing = ();
      for $line (split(/\n/, $output)) {
        next if "$line" eq "";
        push(@curr_keys, "$line");
      }
      for $dest_key (@$dest_keys_ref) {
        $found = 0;
        for $curr_key (@curr_keys) {
          if ($dest_key eq $curr_key) {
            $found = 1;
            last;
          }
        }
        push(@missing, $dest_key) if ($found == 0);
      }

      print "DEBUG: ", __LINE__, " gen_dest_keys(): num of missing=", scalar @missing, "\n" if $debug;
      if (scalar @missing > 0) {
        $items = join("\n", @missing);
        open($fh, "| ssh -T root\@$h \"cat >> $file\"") or
          die "ERROR: gen_dest_keys(): Failed to connect to $h for appending $file.\n";
        print $fh "$items\n";
        close $fh;
        print "$file changed on $h.\n";
      }
    }
    $j++;
  } # for $h (@hosts)
} # gen_dest_keys()

# Add host finger prints to user and root
# Add user pub keys to user, root pub keys to root
for $type ("host", "user") {
  for $user ("root", $user) {
    get_src_keys($type, $user);
    gen_dest_keys($type, $user);
  }
}

# Add user pub keys to root's authorized_keys
get_src_keys("user", $user);
gen_dest_keys("user", $user, "root");

# Add root pub keys to user's authorized_keys
get_src_keys("user", "root");
gen_dest_keys("user", "root", $user);

exit 0;
