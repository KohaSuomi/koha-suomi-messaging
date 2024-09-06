#!/usr/bin/perl
use warnings;
use strict;
use utf8;

# use Data::Dumper;
use POSIX qw ( strftime );

use C4::Letters qw ( GetPrintMessages GetSuomiFiMessages );
use C4::Context;

use Pate::Modules::Format::PDF;
use Pate::Modules::Format::EPL;
use Pate::Modules::Format::SuomiFi;

use Pate::Modules::Deliver::SOAP;
use Pate::Modules::Deliver::DispatchXML;
use Pate::Modules::Deliver::File;

use Koha::Plugin::Fi::KohaSuomi::SsnProvider::Modules::Database;

use PDF::API2;

binmode STDOUT, ':encoding(utf8)';
binmode STDERR, ':encoding(utf8)';

my $letters = 0;
my $undelivered = 0;

our $pseudotime=time();
our $filename;

sub find_branchconfig {
    my ( $section, $message ) = @_;

    # Format and transit will be defined by the branch, or 'default'.
    # Why does C4::Context return sometimes undef and sometimes empty hash here on the exact same query???
    if ( C4::Context->config('ksmessaging')->{$section}->{'branches'}->{"@$message{'branchcode'}"} && keys %{ C4::Context->config('ksmessaging')->{$section}->{'branches'}->{"@$message{'branchcode'}"} } ) {
        return "@$message{'branchcode'}";
    }
    return "default";
}

unless (C4::Context->config('ksmessaging')) {
    print STDERR "No configuration found for ksmessaging.\n";
    exit 1;
}

if ( $ARGV[0] eq '--help' ) {
    print "\nUsage: $0 --letters | --letters-as-suomifi | --suomifi [testihetu]\n\n";
    exit 1;
}

my $testID = $ARGV[1] if ( $ARGV[1] );

unless ( $ARGV[0] ) {
    print "\nSelect either '--letters', '--letters-as-suomifi' or '--suomifi'.\n" unless ( $ARGV[0] );
}

elsif ( $ARGV[0] eq '--suomifi' ) {

    foreach my $message ( @{ GetSuomiFiMessages() } ) {
        $letters++;

        my $branchconfig = find_branchconfig('suomifi', $message);

        if ( C4::Context->config('ksmessaging')->{'suomifi'}->{'branches'}->{"$branchconfig"}->{'wsapi'} ) {
            if ( my $formattedmessage = SOAPEnvelope ( %{$message}, 'branchconfig' => $branchconfig ) ) {
                # Debug
                if ( $ENV{'DEBUG'} && $ENV{'DEBUG'} == 1 ) {
                    print STDERR "\n=== Unsigned message " . @$message{'message_id'} . " ===\n\n";
                    print STDERR $formattedmessage;
                }

                # Sign SOAP message with Java/Apache WSSEC
                my $signedmessage = callSOAPSigner ( 'branchconfig' => $branchconfig, 'message' => $formattedmessage );

                # Debug
                if ( $ENV{'DEBUG'} && $ENV{'DEBUG'} == 1 ) {
                    print STDERR "\n=== Signed message " . @$message{'message_id'} . " ===\n\n";
                    print STDERR $signedmessage;
                }

                # Send letter and mark it sent or failed
                if ( POSTSOAP $signedmessage ) {;
                    C4::Letters::_set_message_status ( { message_id => @$message{'message_id'},
                                                         status     => 'sent' } );
                }
                else {
                   C4::Letters::_set_message_status ( { message_id => @$message{'message_id'},
                                                        status     => 'failed' } );
                   $undelivered++;
                }
            }
            else {
                print STDERR "Can't generate message @$message{'message_id'} for borrower @$message{'borrowernumber'}, no SSN available?\n";

                C4::Letters::_set_message_status ( { message_id => @$message{'message_id'},
                                                     status     => 'failed' } );
                $undelivered++;
            }
        } elsif ( C4::Context->config('ksmessaging')->{'suomifi'}->{'branches'}->{"$branchconfig"}->{'ipostpdf'} ) {
            my $ssndb = Koha::Plugin::Fi::KohaSuomi::SsnProvider::Modules::Database->new();
            my $ssn = $testID || eval { $ssndb->getSSNByBorrowerNumber ( @$message{'borrowernumber'} ) };

            if ( $@ ) {
                print STDERR "Error getting SSN: $@\n";
            }

            unless ( $ssn ) {
                print STDERR "No suomi.fi message created for message " . @$message{'message_id'}. ". No SSN available.\n";

                C4::Letters::_set_message_status ( { message_id => @$message{'message_id'},
                                                     status     => 'failed' } );

                # We'll consider this non-fatal and keep on going with other messages
                $undelivered++;
                next;
            }
            process_suomifi_letters($message, $branchconfig);
        } else {
             print STDERR "No suomi.fi message created for message " . @$message{'message_id'}. ". The format for the branch is not configured.\n";

             C4::Letters::_set_message_status ( { message_id => @$message{'message_id'},
                                                  status     => 'failed' } );

             # We'll consider this non-fatal and keep on going with other messages
             $undelivered++;
             next;
        }

    }

}
elsif ($ARGV[0] eq '--letters-as-suomifi') {
    print STDERR "Staging letters as Suomi.fi messages...\n";

    foreach my $message ( @{ GetPrintMessages() } ) {
        # Skip defined letter_codes from the process
        if ( C4::Context->config('ksmessaging')->{'letters'}->{'skipletters'} ) {
            my $skipletter = 0;
            my @skip = split(',', C4::Context->config('ksmessaging')->{'letters'}->{'skipletters'});
            foreach my $skip (@skip) {
                if (@$message{'letter_code'} eq $skip) {
                    $skipletter = 1;
                    last;
                }
            }
            next if $skipletter;
        }
        $letters++;

        my $branchconfig = find_branchconfig('suomifi', $message);

        if ( C4::Context->config('ksmessaging')->{'suomifi'}->{'branches'}->{"$branchconfig"}->{'ipostpdf'} ) {
            process_suomifi_letters($message, $branchconfig);
        } else {
            print STDERR "No suomi.fi message created for message " . @$message{'message_id'}. ". The format for the branch is not configured.\n";

            C4::Letters::_set_message_status ( { message_id => @$message{'message_id'},
                                                 status     => 'failed' } );

            # We'll consider this non-fatal and keep on going with other messages
            $undelivered++;
            next;
        }
    }
}
elsif ( $ARGV[0] eq '--letters' ) {
    print STDERR "Staging letters...\n";

    foreach my $message ( @{ GetPrintMessages() } ) {
        # Skip defined letter_codes from the process
        if ( C4::Context->config('ksmessaging')->{'letters'}->{'skipletters'} ) {
            my $skipletter = 0;
            my @skip = split(',', C4::Context->config('ksmessaging')->{'letters'}->{'skipletters'});
            foreach my $skip (@skip) {
                if (@$message{'letter_code'} eq $skip) {
                    $skipletter = 1;
                    last;
                }
            }
            next if $skipletter;
        }
        $letters++;
        # Combining will happen here

        my $branchconfig = find_branchconfig('letters', $message);

        if ( $ENV{'DEBUG'} ) {
            print @$message{'branchcode'} . "\n";
            print Dumper ( C4::Context->config('ksmessaging')->{'letters'}->{'branches'}->{"@$message{'branchcode'}"}  );
        }

        if ( C4::Context->config('ksmessaging')->{'letters'}->{'branches'}->{"$branchconfig"}->{'ipostepl'} ) {
            my $encoding = C4::Context->config('ksmessaging')->{'letters'}->{'branches'}->{"$branchconfig"}->{'ipostepl'}->{'encoding'} || 'latin1';
            my $fileprefix = C4::Context->config('ksmessaging')->{'letters'}->{'branches'}->{"$branchconfig"}->{'ipostepl'}->{'fileprefix'} || '';
            my $formattedmessage = toEPL ( %{$message}, 'branchconfig' => $branchconfig );

            # Debug
            if ( $ENV{'DEBUG'} && $ENV{'DEBUG'} == 1 ) {
                print STDERR "\n=== Message " . @$message{'message_id'} . " handled for branch '" . $branchconfig . "' with EPL-pipe ===\n\n";
                print STDERR $formattedmessage;
            }

            $filename = @$message{'branchcode'} . '-' . @$message{'message_id'} . '.epl';
            $filename = $fileprefix . $filename;

            # Write file
            WriteiPostEPL ( 'branchconfig' => $branchconfig, 'epl' => $formattedmessage, 'filename' => $filename, 'encoding' => $encoding );
        }

        elsif ( C4::Context->config('ksmessaging')->{'letters'}->{'branches'}->{"$branchconfig"}->{'ipostpdf'} ) {
            my $pdfname = 'letter-' . @$message{'message_id'} . '.pdf';
            my $formattedmessage = toPDF ( %{$message} );

            my $dispatch = 'letter-' . @$message{'message_id'} . '.xml';
            my $dispatchXML = DispatchXML ( 'interface'      => 'letters',
                                            'borrowernumber' => @$message{'borrowernumber'},
                                            'SSN'            => 'N/A',
                                            'filename'       => $pdfname,
                                            'branchconfig'   => $branchconfig,
                                            'letterid'       => @$message{'message_id'},
                                            'subject'        => @$message{'subject'},
                                            'totalpages'     => getNumberOfPages($formattedmessage) );

            # Debug
            if ( $ENV{'DEBUG'} && $ENV{'DEBUG'} == 1 ) {
                print STDERR "\n=== Message " . @$message{'message_id'} . " handled for branch '" . $branchconfig . "', binary format (PDF) only dispatch data shown ===\n\n";
                print STDERR $dispatchXML;
            }

            # Put files in an iPostPDF archive
            $filename = @$message{'branchcode'} . '-' . @$message{'message_id'} . '.zip';
            WriteiPostArchive ( 'interface'    => 'letters',
                                'pdf'          => $formattedmessage,
                                'xml'          => $dispatchXML,
                                'pdfname'      => $pdfname,
                                'xmlname'      => $dispatch,
                                'branchconfig' => $branchconfig,
                                'filename'     => $filename );
        }

        else {
            if ( $branchconfig eq 'default' ) {
                print STDERR "No letter created for message " . @$message{'message_id'}. ". Process this manually with a plugin!\n";

                # We'll consider this non-fatal and keep on going with other messages
                $undelivered++;
                next;
            }
        }

        # Send with SFTP/FTP (get file transfer configuration separately from letter-format and layout config, so that configuration
        # can be kept simple. Mark letters still pending sent or failed.
        $branchconfig = 'default';
        if ( C4::Context->config('ksmessaging')->{'letters'}->{'branches'}->{"@$message{'branchcode'}"}->{'filetransfer'} &&  C4::Context->config('ksmessaging')->{'letters'}->{'combineacrossbranches'} ne 'yes' ) {
            $branchconfig = @$message{'branchcode'}
        }

        print STDERR "\n=== Transferring '$filename' with '$branchconfig' configuration ===\n" if $ENV{'DEBUG'};
        if ( FileTransfer ( 'interface' => 'letters', 'branchconfig' => $branchconfig, 'filename' => $filename ) ) {
            C4::Letters::_set_message_status ( { message_id => @$message{'message_id'},
                                                 status     => 'sent' } );
            print STDERR "File transfer completed.\n";
        }
        else {
            C4::Letters::_set_message_status ( { message_id => @$message{'message_id'},
                                                 status     => 'failed' } );
            $undelivered++;
            print STDERR "File transfer failed.\n";
        }
    }
}

print STDERR "\n" . $letters . " messages processed, " . $undelivered . " undelivered.\n";
exit 0 if $undelivered > 0;
exit 1;

sub process_suomifi_letters {
    my $message = shift;
    my $branchconfig = shift;

    my $senderid;
    $senderid=C4::Context->config('ksmessaging')->{'suomifi'}->{'branches'}->{"$branchconfig"}->{'ipostpdf'}->{'senderid'}
        if ( C4::Context->config('ksmessaging')->{'suomifi'}->{'branches'}->{"$branchconfig"}->{'ipostpdf'}->{'senderid'} );

    die "Mandatory parameter senderid is not set for branch." unless ( $senderid );

    # Set fileprefix same as senderid or override if prefix is set in config
    my $fileprefix=$senderid;
    $fileprefix=C4::Context->config('ksmessaging')->{'suomifi'}->{'branches'}->{"$branchconfig"}->{'ipostpdf'}->{'fileprefix'}
        if ( C4::Context->config('ksmessaging')->{'suomifi'}->{'branches'}->{"$branchconfig"}->{'ipostpdf'}->{'fileprefix'} );

    # Define filename
    $filename = $fileprefix . "_";

    # Run time backwards to make suomi.fi happy with our filenames
    $pseudotime--;
    $filename .= strftime( "%Y%m%d%H%M%S", localtime($pseudotime) );

    my $pdfname = @$message{'message_id'} . '.pdf';
    #my $formattedmessage = setMediaboxByPage ( toPDF ( %{$message} ) );
    my $formattedmessage = toPDF ( %{$message} );
    my $dispatch = @$message{'message_id'} . '.xml';

    my $ssndb = Koha::Plugin::Fi::KohaSuomi::SsnProvider::Modules::Database->new();
    my $ssn = $testID || eval { $ssndb->getSSNByBorrowerNumber ( @$message{'borrowernumber'} ) };

    if ( $@ ) {
        print STDERR "Error getting SSN: $@\n";
    }

    unless ( $ssn ) {
        $filename .= "_suoratulostus";
    }
    
    $filename .= '_' . C4::Context->config('ksmessaging')->{'suomifi'}->{'branches'}->{"$branchconfig"}->{'ipostpdf'}->{'printprovider'}
        if ( C4::Context->config('ksmessaging')->{'suomifi'}->{'branches'}->{"$branchconfig"}->{'ipostpdf'}->{'printprovider'} );

    $filename .= ".zip";
    my $dispatchXML = DispatchXML ( 'interface'      => 'suomifi',
                                    'borrowernumber' => @$message{'borrowernumber'},
                                    'SSN'            => $ssn || 'N/A', # 'N/A' is a placeholder for 'no SSN available
                                    'filename'       => $pdfname,
                                    'branchconfig'   => $branchconfig,
                                    'letterid'       => @$message{'message_id'},
                                    'subject'        => @$message{'subject'},
                                    'totalpages'     => getNumberOfPages($formattedmessage) );

    # Debug
    if ( $ENV{'DEBUG'} && $ENV{'DEBUG'} == 1 ) {
        print STDERR "\n=== Message " . @$message{'message_id'} . " handled for branch 'default', binary format (PDF) only dispatch data shown ===\n\n";
        print STDERR $dispatchXML;
    }

    # Put files in an iPostPDF archive
    WriteiPostArchive ( 'interface'    => 'suomifi',
                        'pdf'          => $formattedmessage,
                        'xml'          => $dispatchXML,
                        'pdfname'      => $pdfname,
                        'xmlname'      => $dispatch,
                        'branchconfig' => $branchconfig,
                        'filename'     => $filename );


    # Select file transfer configuration for branch or default
    $branchconfig = 'default';
    $branchconfig = @$message{'branchcode'} if ( C4::Context->config('ksmessaging')->{'suomifi'}->{'branches'}->{"@$message{'branchcode'}"}->{'filetransfer'} );

    print STDERR "\n=== Transferring with '$branchconfig' configuration ===\n" if $ENV{'DEBUG'};

    if ( FileTransfer ( 'interface' => 'suomifi', 'branchconfig' => "$branchconfig", 'filename' => "$filename" ) ) {
        C4::Letters::_set_message_status ( { message_id => @$message{'message_id'},
                                                status     => 'sent' } );
        print STDERR "File transfer completed.\n";
    }
    else {
        C4::Letters::_set_message_status ( { message_id => @$message{'message_id'},
                                                status     => 'failed' } );
        print STDERR "File transfer failed.\n";
        $undelivered++;
    }
}
