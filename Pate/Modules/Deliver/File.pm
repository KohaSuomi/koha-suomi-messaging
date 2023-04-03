#/usr/bin/perl
use warnings;
use strict;
use utf8;

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

use Net::SFTP::Foreign;
use Net::FTP;

sub WriteiPostEPL {
    my %param = @_;
    my $letters;
    my $encoding = $param{'encoding'} || 'latin1';

    if ($encoding eq 'latin1') {
        # Replace unconverted characters  with ? to prevent \x{...} mess in letter.
        open ( LETTERS, ">encoding(latin1)", \$letters );
        print LETTERS $param{'epl'};
        close LETTERS;

        $letters =~ s/\\x\{....\}/?/g;
    } else {
        $letters = $param{'epl'};
    }

    # Make target directory if needed
    my $stagingdir =
      C4::Context->config('ksmessaging')->{'letters'}->{'branches'}->{"$param{'branchconfig'}"}->{'stagingdir'};

    unless ( -d "$stagingdir" ) {
        mkdir "$stagingdir" or die localtime . ": Can't create directory $stagingdir.";
    }

    # Then write to disk
    open ( LETTERS, ">encoding(".$encoding.")", $stagingdir . '/' . $param{'filename'} )
      or die localtime . ": Can't write to " . $stagingdir . '/' . $param{'filename'} . ".";

    print LETTERS $letters;
    close LETTERS;
}

sub WriteiPostArchive {
    my %param = @_;

    # Determine and make target directory if needed
    my $stagingdir = C4::Context->config('ksmessaging')->{"$param{'interface'}"}->{'branches'}->{"$param{'branchconfig'}"}->{'stagingdir'};
    unless ( -d "$stagingdir" ) {
        mkdir "$stagingdir" or die localtime . ": Can't create directory $stagingdir.";
    }

    my $zip = Archive::Zip->new();

    # Place data inside the archive as files
    $zip->addString ( $param{'pdf'}, $param{'pdfname'} );
    $zip->addString ( $param{'xml'}, $param{'xmlname'} );

    # If old archive exists with the same name, destroy it 
    if ( -e $stagingdir . '/' . $param{'filename'} ) {
        warn localtime . ": Older archive with the same name ". $param{'filename'} . " already exists, overwriting!";
        unlink $stagingdir . '/' . $param{'filename'};  
    }

    # Create new archive
    $zip->writeToFileNamed($stagingdir . '/' . $param{'filename'}) == AZ_OK or die localtime . ": Can't create archive " . $stagingdir . '/' . $param{'filename'} . '.';
}

sub GetTransferConfig {
    my %param = @_;
    my %config;

    $config{"$_"} = C4::Context->config('ksmessaging')->{"$param{'interface'}"}->{'branches'}->{"$param{'branchconfig'}"}->{'filetransfer'}->{"$_"}
    foreach ( qw ( host port remotedir user password protocol ) );

    return %config;
}

sub FileTransfer {
    my %param = @_;

    # This defines where the files to be transferred were put
    my $stagingdir = C4::Context->config('ksmessaging')->{"$param{'interface'}"}->{'branches'}->{"$param{'branchconfig'}"}->{'stagingdir'};

    my %config = GetTransferConfig('interface' => "$param{'interface'}", 'branchconfig' => "$param{'branchconfig'}");
    $config{'remotedir'}  = '~' unless $config{'remotedir'}; # Default dir

    if ( $config{'host'} && $config{'user'} && $config{'password'} && $config{'protocol'} ) {
        # Tell the user what is happening
        print STDERR "\nSending $stagingdir/$param{'filename'} to $config{'user'}\@$config{'host'}:$config{'remotedir'} port $config{'port'} with $config{'protocol'}\n";

        if ( $config{'protocol'} eq 'sftp' ) {
            $config{'port'} = 22  unless $config{'port'}; # Default port for sftp

            # Connect and send with SFTP
            my $sftp = Net::SFTP::Foreign->new ( 'host'     => $config{'host'},
                                                 'port'     => $config{'port'},
                                                 'user'     => $config{'user'},
                                                 'password' => $config{'password'} );

            if ( $sftp->error ) {
                print STDERR "Logging in to SFTP server failed.\n";
                return 0;
            }
            unless ( $sftp->put ( $stagingdir . '/' . $param{'filename'}, $config{'remotedir'} . '/' . $param{'filename'} . '.part' ) ) {
                print STDERR "Transferring file to SFTP server failed.\n";
                return 0;
            }
            unless ( $sftp->rename ( $config{'remotedir'} . '/' . $param{'filename'} . '.part', $config{'remotedir'} . '/' . $param{'filename'} ) ) {
                print STDERR "Renaming a file on SFTP server failed.\n";
                return 0;
            }
        }
        elsif ( $config{'protocol'} eq 'ftp' ) {
            $config{'port'} = 21  unless $config{'port'}; # Default port for ftp

            # Connect and send with FTP
            my $ftp = Net::FTP->new ( 'Host'     => $config{'host'},
                                      'Port'     => $config{'port'},
                                      'Passive'  => 1,
                                      'Debug'    => 1 );

            unless ( $ftp->login ( $config{'user'}, $config{'password'} ) ) {
                print STDERR "Logging in to FTP server failed.\n";
                return 0;
            }
            unless ( $ftp->put ( $stagingdir . '/' . $param{'filename'}, $config{'remotedir'} . '/' . $param{'filename'} . '.part' ) ) {
                print STDERR "Transfering file to FTP server failed.\n";
                return 0;
            }
            unless ( $ftp->rename ( $config{'remotedir'} . '/' . $param{'filename'} . '.part', $config{'remotedir'}. '/' . $param{'filename'} ) ) {
                print STDERR "Renaming a file on FTP server failed.\n";
                return 0;
            }
        }
        else {
            print STDERR "Unknown protocol " . $config{'protocol'} . ".\n";
            return 0;
        }
    }
    else {
        print STDERR "File transfer skipped (not configured).\n";
        return 1; # This is not an error as such, just let the user know what happened.
    }
}

1;
