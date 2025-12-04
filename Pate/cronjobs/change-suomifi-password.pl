#!/usr/bin/perl

use Modern::Perl;
use Pate::Modules::Deliver::REST;
use Getopt::Long;
use Try::Tiny;
use Pate::Modules::Config;
use String::Random qw( random_string );
use Koha::Caches;
use XML::LibXML;
use POSIX qw(strftime);

my $help;
my $verbose = 0;
my $branchcode = 'default';
my $old_password;
my $write_config = 0;
my $backup;
my $test_password = 0;

GetOptions(
    'help' => \$help,
    'verbose|v' => \$verbose,
    'branchcode=s' => \$branchcode,
    'old_password=s' => \$old_password,
    'write_config' => \$write_config,
    'backup=s' => \$backup,
    'test_password' => \$test_password
);

if ($help) {
    print "Usage: $0 [--branchcode=BRANCHCODE] [--old_password=OLD_PASSWORD] [--write_config] [--backup=BACKUP] [--test_password]\n";
    print "--branchcode: Specify the branch code (default: 'default')\n";
    print "--old_password: Provide the old password if you want to test it before changing\n";
    print "--write_config: If set, the new password will be written to the config file\n";
    print "--backup: Specify a file to back up the new password (default: /var/spool/koha/suomifi_password_backup.txt)\n";
    print "--test_password: If set, the script will only test the old password without changing it\n";
    exit 0;
}

my $config = Pate::Modules::Config->new({
    interface => 'suomifi',
    branch => $branchcode,
});

my $start_time = strftime "%Y-%m-%d %H:%M:%S", localtime;
print "Script started at $start_time\n" if $verbose;
END {
    my $end_time = strftime "%Y-%m-%d %H:%M:%S", localtime;
    print "Script ended at $end_time\n" if $verbose;
}

# Generate and store the new password in a file for recovery if needed
my $new_password = generate_password();

unless ($test_password) {
    # Save the new password to a backup file before proceeding
    my $backup_file = $backup || "/var/spool/koha/suomifi_password_backup.txt";
    open my $fh, '>', $backup_file or die "Could not open $backup_file for writing: $!";
    print $fh "$new_password\n" if $fh;
    close $fh if $fh;
    print "New password backed up to $backup_file\n" if $verbose;
}

my $restConfig = $config->getRESTConfig();
my $password = $old_password || $restConfig->{password};
my $restClass = Pate::Modules::Deliver::REST->new({baseUrl => $restConfig->{baseUrl}});
my $cache = Koha::Caches->get_instance();
my $accessToken = $test_password ? undef : $cache->get_from_cache($config->cacheKey());
try {
    unless ($accessToken) {
        print "Fetching a access token\n" if $verbose;
        my $tokenResponse = $restClass->fetchAccessToken('/v1/token', 'application/json', {password => $password, username => $restConfig->{username}});
        $accessToken = $tokenResponse->{access_token};
        #Token should be valid for 5 seconds less than the expiry time
        $cache->set_in_cache($config->cacheKey(), $accessToken, { expiry => $tokenResponse->{expires_in} - 5 });
    }
    if ($test_password) {
        print "The provided old password is correct.\n";
        exit 0;
    }
    sleep 2; #Ensure token is valid
    my $response = $restClass->changePassword('/v1/change-password', 'application/json', {accessToken => $accessToken, currentPassword => $password, newPassword => $new_password});
    print "Password changed to $new_password\n" if $verbose;
    if ($write_config) {
        find_and_replace_password($restConfig->{username}, $new_password);
    } else {
        print "Not writing to config file, use --write_config to enable this.\n";
        print "Add the new password to your config file manually.\n";
    }
    $cache->clear_from_cache($config->cacheKey());
} catch {
    print "$_\n";
};

sub generate_password {
    my $random = String::Random->new;
    my $password;
    do {
        $password = $random->randpattern("CCcc!n" x 8); # 8 sets of upper, lower, symbol, and number
    } while ($password =~ /[&<>'"]/); # Regenerate if it contains an ampersand, less than, or greater than symbol or a single quote or double quote
    return $password;
}

sub find_and_replace_password {
    my ($username, $new_password) = @_;

    my $config_file = $ENV{KOHA_CONF} || '/etc/koha/koha-conf.xml';

    my $parser = XML::LibXML->new();
    my $doc = $parser->parse_file($config_file);

    # Find the <rest> element with the desired <serviceid>
    foreach my $rest ($doc->findnodes('//rest')) {
        my ($file_username) = $rest->findnodes('./username');
        next unless $file_username;
        if ($file_username->textContent eq $username) {
            my ($password) = $rest->findnodes('./password');
            if ($password) {
                $password->removeChildNodes();
                $password->appendText($new_password);
            } else {
                # If <password> doesn't exist, create it
                my $new_pw_node = $doc->createElement('password');
                $new_pw_node->appendText($new_password);
                $rest->appendChild($new_pw_node);
            }
        }
    }

    # Save the updated XML
    $doc->toFile($config_file);
    print "Password updated in $config_file\n";
}