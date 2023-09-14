package Words::Trans::Freedic;

use 5.36.0;
use utf8;
use Data::Dumper;
use LWP::UserAgent;
use JSON -convert_blessed_universally;
use Try::Tiny;
use Exporter qw(import);

our @EXPORT_OK = qw(translate);

my $api   = "https://api.dictionaryapi.dev/api/v2/entries/en/";

# translate('shift');
sub translate {
    my $query = shift;

    my $ua    = LWP::UserAgent->new();
    $ua->agent("Mozilla/5.0");
    $ua->timeout(10);
    my $state = 1;

    my $json_data = "{}";
    my $response = $ua->get($api . "$query");
    unless ($response->is_success) {
        $state = 0;
    }
    else {
        $json_data = $response->decoded_content;
    }

    my $perl_data = JSON->new->allow_nonref->convert_blessed->decode($json_data);

    my %want = ();
    try {
        $want{query} = $query // 'none';
        $want{phonetic} = $perl_data->[0]->{phonetic} // 'none';
        $want{definitions} = do {
            my $str = "";
            foreach my $data (@{$perl_data->[0]->{meanings}}) {
                if ( defined $data->{definitions}->[0]->{example} ) {
                    $str .= $data->{partOfSpeech}.'. '.$data->{definitions}->[0]->{definition}." example: ".$data->{definitions}->[0]->{example}.";;";
                }
                else {
                    $str .= $data->{partOfSpeech}.'. '.$data->{definitions}->[0]->{definition}.";;";
                }
            }
            $str; 
        };
    } catch {
        $state = 0;
    };
    # print Dumper(%want) =~ s/\\x\{([0-9a-f]{2,})\}/chr hex $1/ger;
    return (\%want, $state);
}

1;
