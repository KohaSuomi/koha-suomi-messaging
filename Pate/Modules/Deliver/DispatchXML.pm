#!/usr/bin/perl
use warnings;
use strict;
use utf8;

use Koha::Patrons;

use Encode;
use XML::Simple;
use HTML::Template;

sub GetDispatcherConfig {
    my %param = @_;
    my %config;
    $config{'contact'}      = C4::Context->config('ksmessaging')->{"$param{'interface'}"}->{'branches'}->{"$param{'branchconfig'}"}->{'contact'};
    $config{'customerId'}   = C4::Context->config('ksmessaging')->{"$param{'interface'}"}->{'branches'}->{"$param{'branchconfig'}"}->{'ipostpdf'}->{'customerid'};
    $config{'customerPass'} = C4::Context->config('ksmessaging')->{"$param{'interface'}"}->{'branches'}->{"$param{'branchconfig'}"}->{'ipostpdf'}->{'customerpass'};
    $config{'ovtId'}        = C4::Context->config('ksmessaging')->{"$param{'interface'}"}->{'branches'}->{"$param{'branchconfig'}"}->{'ipostpdf'}->{'ovtid'};
    $config{'senderId'}     = C4::Context->config('ksmessaging')->{"$param{'interface'}"}->{'branches'}->{"$param{'branchconfig'}"}->{'ipostpdf'}->{'senderid'};
    return %config;
}

sub DispatchXML {
    my %param = @_;
    my %sender = GetDispatcherConfig( 'interface' => $param{'interface'}, 'branchconfig' => $param{'branchconfig'} );
    my $borrower = Koha::Patrons->find( $param{'borrowernumber'} );

    my $userHomeDir = (getpwuid($<))[7];
    my $templateDir = $userHomeDir . '/koha-suomi-messaging/Pate/Templates/'; # Dynamically set the template directory
    my $xmlTemplate = HTML::Template->new( filename => $templateDir . 'DispatchXML.tmpl' );

       $xmlTemplate->param( SENDERID     => $sender{'senderId'} );
       $xmlTemplate->param( CONTACT      => $sender{'contact'} );
       $xmlTemplate->param( CUSTOMERID   => $sender{'customerId'} );
       $xmlTemplate->param( CUSTOMERPASS => $sender{'customerPass'} );
       $xmlTemplate->param( OVTID        => $sender{'ovtId'} );

       $xmlTemplate->param( SSN          => XML::Simple->new()->escape_value( $param{'SSN'} ) );
       $xmlTemplate->param( NAME         => XML::Simple->new()->escape_value( $borrower->firstname ) );
       $xmlTemplate->param( SURNAME      => XML::Simple->new()->escape_value( $borrower->surname ) );
       $xmlTemplate->param( ADDRESS1     => XML::Simple->new()->escape_value( $borrower->address ) );
       $xmlTemplate->param( ZIPCODE      => XML::Simple->new()->escape_value( $borrower->zipcode ) );
       $xmlTemplate->param( CITY         => XML::Simple->new()->escape_value( $borrower->city ) );

       $xmlTemplate->param( LETTERID     => $param{'letterid'} );
       $xmlTemplate->param( SUBJECT      => $param{'subject'} );
       $xmlTemplate->param( TOTALPAGES   => $param{'totalpages'} );

       $xmlTemplate->param( EXFILENAME   => $param{'filename'});

    return $xmlTemplate->output;
}

1;
