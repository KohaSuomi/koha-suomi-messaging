#!/usr/bin/perl

use Modern::Perl;
use Pate::Modules::Deliver::REST;
use Getopt::Long;
use Try::Tiny;
use Pate::Modules::Config;
use String::Random qw( random_string );
use Koha::Caches;
use XML::LibXML;

my $help;
my $branchcode = 'default';
my $old_password;
my $write_config = 0;

GetOptions(
    'help' => \$help,
    'branchcode=s' => \$branchcode,
    'old_password=s' => \$old_password,
    'write_config' => \$write_config,
);

if ($help) {
    print "Usage: $0 [--branchcode=BRANCHCODE] [--old_password=OLD_PASSWORD] [--write_config]\n";
    exit;
}
my $config = Pate::Modules::Config->new({
    interface => 'suomifi',
    branch => $branchcode,
});

my $new_password = generate_password();

my $restConfig = $config->getRESTConfig();
my $password = $old_password || $restConfig->{password};
my $restClass = Pate::Modules::Deliver::REST->new({baseUrl => $restConfig->{baseUrl}});
my $cache = Koha::Caches->get_instance();
my $accessToken = $cache->get_from_cache($config->cacheKey());
try {
    unless ($accessToken) {
        print "Fetching a access token\n";
        my $tokenResponse = $restClass->fetchAccessToken('/v1/token', 'application/json', {password => $password, username => $restConfig->{username}});
        $accessToken = $tokenResponse->{access_token};
        #Token should be valid for 5 seconds less than the expiry time
        $cache->set_in_cache($config->cacheKey(), $accessToken, { expiry => $tokenResponse->{expires_in} - 5 });
    }
    my $response = $restClass->changePassword('/v1/change-password', 'application/json', {accessToken => $accessToken, currentPassword => $password, newPassword => $new_password});
    if ($write_config) {
        find_and_replace_password($restConfig->{username}, $new_password);
    } else {
        print "Password changed to $new_password\n";
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