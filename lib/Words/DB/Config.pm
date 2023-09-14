package Words::DB::Config;

# Set the user and passwd of MySql
# The config file will under ~/.config/words

use 5.36.0;
use utf8;
use Term::ReadKey;
use Exporter qw(import);

our @EXPORT = qw($config_file read_key);

check_sql();
my $config_dir = "$ENV{'HOME'}/.config/";
my $config_file = $config_dir . "words";

if ( !-e $config_file ) {
    mkdir if (!-d $config_dir);
    open my $fh, '>', $config_file
        or die "Can not create $config_file";
    close $fh;

    set_config();
}

sub check_sql {
    my $sql_ok = `mysql --version`;
    my $mariadb_ok = `mariadb --version`;
    if (!defined $sql_ok and !defined $mariadb_ok) {
        print "Please install mysql or mariadb"; 
        exit;
    }
}

sub set_config {
    print "Enter you user name: ";
    my $sql_username = ReadLine(0);
    print "Enter you password (It will be hidden on command line): ";
    ReadMode('noecho');
    my $sql_passwd = ReadLine(0);
    ReadMode('restore');
    print "\n";

    chomp_array(\$sql_username, \$sql_passwd);

    open my $fh, '>', $config_file
        or die "Can not create $config_file";
    print {$fh} "user: $sql_username\npasswd: $sql_passwd";
    close $fh;
}

sub chomp_array {
    chomp ${$_} foreach @_;
}

sub read_key {
    my $key = shift;

    open my $fh, "<", $config_file
        or die "Can not open $config_file";

    while (<$fh>) {
        local $1;
        if (m/$key:/) {
            my $line = $_;
            chomp ($line);
            my ($value) = $line =~ s/$key: (.*)/$1/r;
            return $value;
        }
    }
}


1;
