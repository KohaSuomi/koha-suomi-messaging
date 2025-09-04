package Pate::Modules::Config;

use Modern::Perl;
use C4::Context;

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
