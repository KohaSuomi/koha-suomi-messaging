#!/usr/bin/perl

use Modern::Perl;
use Pate::Modules::Deliver::REST;
use Getopt::Long;
use Try::Tiny;
use Pate::Modules::Config;
use String::Random qw( random_string );
use Koha::Caches;

my $help;
my $branchcode = 'default';

GetOptions(
    'help' => \$help,
    'branchcode=s' => \$branchcode,
);

if ($help) {
    print "Usage: $0 [--branchcode=BRANCHCODE]\n";
    exit;
}
my $config = Pate::Modules::Config->new({
    interface => 'suomifi',
    branch => $branchcode,
});

my $new_password = generate_password();

my $restConfig = $config->getRESTConfig();
my $restClass = Pate::Modules::Deliver::REST->new({baseUrl => $restConfig->{baseUrl}});
my $cache = Koha::Caches->get_instance();
my $accessToken = $cache->get_from_cache($config->cacheKey());
try {
    unless ($accessToken) {
        print "Fetching a access token\n" if $ENV{'DEBUG'};
        my $tokenResponse = $restClass->fetchAccessToken('/v1/token', 'application/json', {password => $restConfig->{password}, username => $restConfig->{username}});
        $accessToken = $tokenResponse->{access_token};
        #Token should be valid for 5 seconds less than the expiry time
        $cache->set_in_cache($config->cacheKey(), $accessToken, { expiry => $tokenResponse->{expires_in} - 5 });
    }
    my $response = $restClass->changePassword('/v1/change-password', 'application/json', {accessToken => $accessToken, currentPassword => $restConfig->{password}, newPassword => $new_password});
    print "Password changed to $new_password\n";
    print "Add it to the config file!!!\n";
    $cache->clear_from_cache($config->cacheKey());
} catch {
    print "Error: $_\n";
};

sub generate_password {
    my $random = String::Random->new;
    return $random->randpattern("CCcc!n" x 8); # 8 sets of upper, lower, symbol, and number
}