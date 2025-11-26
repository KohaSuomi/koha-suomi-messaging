package Pate::Modules::Config;

use Modern::Perl;
use C4::Context;
use YAML::XS;
use utf8;
use Encode qw(decode encode);

sub new {
    my ($class, $params) = @_;
    my $self = {};
    $self->{interface} = $params->{interface};
    $self->{branch} = $params->{branch};
    bless($self, $class);
    return $self;
}

sub interface {
    my ($self) = @_;
    return $self->{interface};
}

sub branch {
    my ($self) = @_;
    return $self->{branch};
}

sub branchConfig {
    my ($self) = @_;
    if (C4::Context->config('ksmessaging')->{$self->{interface}}->{'branches'}->{$self->{branch}}) {
        return $self->{branch};
    } else {
        return 'default';
    }
}

sub rootConfig {
    my ($self) = @_;
    return C4::Context->config('ksmessaging')->{$self->{interface}}->{'branches'}->{$self->{branch}} || C4::Context->config('ksmessaging')->{$self->{interface}}->{'branches'}->{'default'};
}

sub stagingDir {
    my ($self) = @_;
    return $self->rootConfig()->{'stagingdir'};
}

sub contact {
    my ($self) = @_;
    return $self->rootConfig()->{'contact'};
}

sub cacheKey {
    my ($self) = @_;
    return $self->rootConfig()->{'cachekey'};
}

sub getRESTConfig {
    my ($self) = @_;
    return {
        'baseUrl'   => $self->rootConfig()->{'rest'}->{baseUrl},
        'username'  => $self->rootConfig()->{'rest'}->{username},
        'password'  => $self->rootConfig()->{'rest'}->{password},
        'serviceid' => $self->rootConfig()->{'rest'}->{serviceid},
    };
}

sub getIPostConfig {
    my ($self) = @_;
    return {
        'customerid'    => $self->rootConfig()->{'ipostpdf'}->{'customerid'},
        'customerpass'  => $self->rootConfig()->{'ipostpdf'}->{'customerpass'},
        'ovtid'         => $self->rootConfig()->{'ipostpdf'}->{'ovtid'},
        'senderid'      => $self->rootConfig()->{'ipostpdf'}->{'senderid'},
        'printprovider' => $self->rootConfig()->{'ipostpdf'}->{'printprovider'},
        'fileprefix'    => $self->rootConfig()->{'ipostpdf'}->{'fileprefix'},
    };
}

sub getFileTransferConfig {
    my ($self) = @_;
    return {
        'host'      => $self->rootConfig()->{'filetransfer'}->{'host'},
        'port'      => $self->rootConfig()->{'filetransfer'}->{'port'},
        'username'  => $self->rootConfig()->{'filetransfer'}->{'username'},
        'password'  => $self->rootConfig()->{'filetransfer'}->{'password'},
        'remotedir' => $self->rootConfig()->{'filetransfer'}->{'remotedir'},
        'protocol'  => $self->rootConfig()->{'filetransfer'}->{'protocol'},

    };
}

=head2

# Example usage of getSuomiFiAltSender:
#
# my $config = Pate::Modules::Config->new({
#     branch    => 'branch_id',
# });
# my $alt_sender = $config->getSuomiFiAltSender( $lang );
# print "Alt sender for branch: $alt_sender\n";
# This method returns the alternative sender value for the given branch, as defined in the
# SuomiFiAltSender system preference (YAML format). If no match is found, it returns undef.

=cut

sub getSuomiFiAltSender {
    my ($self, $lang) = @_;
    
    my $library_id = $self->{branch};
    my $config = C4::Context->preference('SuomiFiAltSender');

    return unless $config;
    my $encoded_config = encode('UTF-8', $config);
    my $yaml = eval { YAML::XS::Load($encoded_config) };
    
    if ($@ ) {
        print "YAML load error: $@\n";
        return;
    }
    if (ref($yaml) ne 'HASH') {
        print "YAML is not a hash reference\n";
        return;
    }

    # First try to find matching language section
    foreach my $lang_key (keys %$yaml) {
        if (defined $lang && $lang ne "default" && $lang eq $lang_key) {
            my $lang_section = $yaml->{$lang_key};
            if (ref($lang_section) eq 'HASH') {
                foreach my $branch (keys %$lang_section) {
                    if ($library_id eq $branch || $library_id =~ /\Q$branch\E/) {
                        return $lang_section->{$branch};
                    }
                }
            } else {
                # If the lang section is not a hash, return it directly
                return $lang_section;
            }
        }
    }
    # Then try to find matching branch section without language
    foreach my $branch (keys %$yaml) {
        if ($library_id eq $branch || $library_id =~ /\Q$branch\E/) {
            return $yaml->{$branch};
        }
    }
    # Then try to find default section
    if (exists $yaml->{default}) {
        return $yaml->{default};
    }

    return;
}

=head2 

# Example usage of getSuomiFiCostPool:
#
# my $config = Pate::Modules::Config->new({
#     branch    => 'branch_id',
# });
# my $cost_pool = $config->getSuomiFiCostPool;
# print "Cost pool for branch: $cost_pool\n";
#
# This method returns the cost pool value for the given branch, as defined in the
# SuomiFiCostPool system preference (YAML format). If no match is found, it returns undef.

=cut

sub getSuomiFiCostPool {
    my ($self) = @_;

    my $library_id = $self->{branch};
    my $config = C4::Context->preference('SuomiFiCostPool');

    return unless $config;

    my $yaml = eval { YAML::XS::Load($config) };
    if ($@ ) {
        print "YAML load error: $@\n";
        return;
    }
    if (ref($yaml) ne 'HASH') {
        print "YAML is not a hash reference\n";
        return;
    }

    foreach my $branch (keys %$yaml) {
        if ($library_id eq $branch || $library_id =~ /\Q$branch\E/) {
            my $value = $yaml->{$branch};
            if (defined $value && $value =~ /^[A-Z0-9]+$/) {
                return $value;
            } else {
                return;
            }
        }
    }
    return;
}

sub countryCode {
    my ($self, $country) = @_;
    
    my %countryCodes = (
        'sverige' => 'SE',
        'ruotsi' => 'SE',
        'sweden' => 'SE',
        'norge' => 'NO',
        'norja' => 'NO',
        'norway' => 'NO',
        'danmark' => 'DK',
        'tanska' => 'DK',
        'denmark' => 'DK'
    );
    $country = defined($country) ? lc($country) : '';
    $country =~ s/^\s+|\s+$//g;
    return $countryCodes{$country} // 'FI';
}

1;
