#!/usr/bin/perl
use warnings;
use strict;
use utf8;

use DateTime;
use C4::Context;
use XML::Simple;
use HTML::Template;
use MIME::Base64;
use JSON;

use Koha::Patrons;
use Koha::Plugin::Fi::KohaSuomi::SsnProvider::Modules::Database;

use Pate::Modules::Format::PDF;

sub FormatDescription {
    my $description =  shift;
       $description =~ s/\r\n/\n/g;
       $description =~ s/</&lt;/g;
       $description =~ s/>/&gt;/g;

    return $description;
}

sub SOAPEnvelope {
    my %param = @_;

    # my $templateDir = C4::Context->config( 'intranetdir' ) . '/C4/KohaSuomi/Pate/Templates/';
    my $templateDir = '/home/koha/koha-suomi-ksmessaging/Pate/Templates/'; # This cannot be harcoded, FIXME:
    # my $templateDir = C4::Context->config('ksmessaging')->{'templatedir'};
    my $xmlTemplate = HTML::Template->new( filename => $templateDir . 'SOAPEnvelope.tmpl' );

    # my $borrower = GetMember ( borrowernumber => $param{'borrowernumber'} );
    my $borrower = Koha::Patrons->find( $param{'borrowernumber'} );
    my $ssndb = Koha::Plugin::Fi::KohaSuomi::SsnProvider::Modules::Database->new();
    my $id = $ssndb->getSSNByBorrowerNumber ( $param{'borrowernumber'} );

    return undef unless $id;

    my $base64data = encode_base64 ( toPDF ( %param ) );
    my $description = FormatDescription ( $param{'content'} );

    my $issue_id = $param{'branchcode'} . '/' . $param{'message_id'};
    my $filename = $param{'branchcode'} . '_' . $param{'message_id'} . '.pdf';

    $xmlTemplate->param( SANOMAVERSIO       => C4::Context->config('ksmessaging')->{'suomifi'}->{'branches'}->{"$param{'branchconfig'}"}->{'wsapi'}->{'viranomainen'}->{'sanomaversio'} );
    $xmlTemplate->param( VARMENNENIMI       => C4::Context->config('ksmessaging')->{'suomifi'}->{'branches'}->{"$param{'branchconfig'}"}->{'wsapi'}->{'viranomainen'}->{'varmennenimi'} );

    $xmlTemplate->param( VIRANOMAISTUNNUS   => C4::Context->config('ksmessaging')->{'suomifi'}->{'branches'}->{"$param{'branchconfig'}"}->{'wsapi'}->{'viranomainen'}->{'viranomaistunnus'} );
    $xmlTemplate->param( PALVELUTUNNUS      => C4::Context->config('ksmessaging')->{'suomifi'}->{'branches'}->{"$param{'branchconfig'}"}->{'wsapi'}->{'viranomainen'}->{'palvelutunnus'} );
    $xmlTemplate->param( KAYTTAJATUNNUS     => C4::Context->config('ksmessaging')->{'suomifi'}->{'branches'}->{"$param{'branchconfig'}"}->{'wsapi'}->{'viranomainen'}->{'kayttajatunnus'} );

    $xmlTemplate->param( YHTEYSNIMI         => C4::Context->config('ksmessaging')->{'suomifi'}->{'branches'}->{"$param{'branchconfig'}"}->{'wsapi'}->{'viranomainen'}->{'yhteyshenkilo'}->{'nimi'} );
    $xmlTemplate->param( YHTEYSEMAIL        => C4::Context->config('ksmessaging')->{'suomifi'}->{'branches'}->{"$param{'branchconfig'}"}->{'wsapi'}->{'viranomainen'}->{'yhteyshenkilo'}->{'email'} );
    $xmlTemplate->param( YHTEYSPUHELIN      => C4::Context->config('ksmessaging')->{'suomifi'}->{'branches'}->{"$param{'branchconfig'}"}->{'wsapi'}->{'viranomainen'}->{'yhteyshenkilo'}->{'puhelin'} );

    $xmlTemplate->param( VONIMI             => C4::Context->config('ksmessaging')->{'suomifi'}->{'branches'}->{"$param{'branchconfig'}"}->{'wsapi'}->{'viranomainen'}->{'osoite'}->{'nimi'} );
    $xmlTemplate->param( VOOSOITE           => C4::Context->config('ksmessaging')->{'suomifi'}->{'branches'}->{"$param{'branchconfig'}"}->{'wsapi'}->{'viranomainen'}->{'osoite'}->{'lahiosoite'} );
    $xmlTemplate->param( VOPOSTINUMERO      => C4::Context->config('ksmessaging')->{'suomifi'}->{'branches'}->{"$param{'branchconfig'}"}->{'wsapi'}->{'viranomainen'}->{'osoite'}->{'postinumero'} );
    $xmlTemplate->param( VOPOSTITOIMIPAIKKA => C4::Context->config('ksmessaging')->{'suomifi'}->{'branches'}->{"$param{'branchconfig'}"}->{'wsapi'}->{'viranomainen'}->{'osoite'}->{'postitoimipaikka'} );
    $xmlTemplate->param( VOMAA              => C4::Context->config('ksmessaging')->{'suomifi'}->{'branches'}->{"$param{'branchconfig'}"}->{'wsapi'}->{'viranomainen'}->{'osoite'}->{'maa'} );

    $xmlTemplate->param( TOIMITTAJA         => C4::Context->config('ksmessaging')->{'suomifi'}->{'branches'}->{"$param{'branchconfig'}"}->{'wsapi'}->{'tulostus'}->{'toimittaja'} );

    $xmlTemplate->param( LAHETYSPVM         => DateTime->now );

    $xmlTemplate->param( OTSIKKO            => $param{'subject'}); # Suomi.fi "nimeke" = otsikko
    $xmlTemplate->param( SANOMATUNNISTE     => $param{'message_id'});
    $xmlTemplate->param( VIRANOMAISTUNNISTE => $param{'issue_id'});

    $xmlTemplate->param( ASNIMI             => $borrower->firstname . ' ' . $borrower->surname );
    $xmlTemplate->param( ASOSOITE           => $borrower->address );
    $xmlTemplate->param( ASPOSTINUMERO      => $borrower->zipcode );
    $xmlTemplate->param( ASPOSTITOIMIPAIKKA => $borrower->city );
    $xmlTemplate->param( ASMAA              => $borrower->country );

    $xmlTemplate->param( ASID               => $id );
    $xmlTemplate->param( ASID_TYYPPI        => 'SSN' ); # CRN for companies, but not supported atm

    $xmlTemplate->param( TIEDOSTONIMI       => $filename );
    $xmlTemplate->param( BASE64DATA         => $base64data );
    $xmlTemplate->param( KUVAUSTEKSTI       => $description );

    return $xmlTemplate->output;
}

sub RESTMessage {
    my %param = @_;

    my $borrower = Koha::Patrons->find( $param{'borrowernumber'} );
    my $branch = Koha::Libraries->find( $param{'branchcode'} );
    my $ssndb = Koha::Plugin::Fi::KohaSuomi::SsnProvider::Modules::Database->new();
    my $id = $ssndb->getSSNByBorrowerNumber ( $param{'borrowernumber'} );

    my $format_json = {
        externalId => $param{'message_id'},
        sender => {
            serviceId => C4::Context->config('ksmessaging')->{'suomifi'}->{'branches'}->{"$param{'branchconfig'}"}->{'rest'}->{'serviceid'},
        },
        recipient => {
            id => $id || ''
        },
        'paperMail' => {
            sender => {
                address => {
                    name => $branch->branchname,
                    streetAddress => $branch->branchaddress1,
                    zipCode => $branch->branchzip,
                    city => $branch->branchcity,
                    countryCode => $branch->branchcountry
                }
            },
            recipient => {
                address => {
                    name => $borrower->firstname . ' ' . $borrower->surname,
                    streetAddress => $borrower->address,
                    zipCode => $borrower->zipcode,
                    city => $borrower->city,
                    countryCode => $borrower->country
                }
            },
            printingAndEnvelopingService => {
                postiMessaging => {
                    contactDetails => {
                        email => C4::Context->config('ksmessaging')->{'suomifi'}->{'branches'}->{"$param{'branchconfig'}"}->{'contact'},
                    },
                    username => C4::Context->config('ksmessaging')->{'suomifi'}->{'branches'}->{"$param{'branchconfig'}"}->{'ipostpdf'}->{'customerid'},
                    password => C4::Context->config('ksmessaging')->{'suomifi'}->{'branches'}->{"$param{'branchconfig'}"}->{'ipostpdf'}->{'customerpass'},
                }
            },
            files => [
                {
                    fileId => $param{'file_id'}
                }
            ]
        },
        electronic => {
            title => $param{'subject'},
            body => $param{'content'},
        }
    };
    
    return to_json ( $format_json );
}

1;
