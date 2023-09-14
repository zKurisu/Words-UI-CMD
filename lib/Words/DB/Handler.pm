package Words::DB::Handler;

use 5.36.0;
use utf8;
use DBI;
use Data::Dumper;
use File::Slurp qw(read_file);
use Words::Trans::Freedic qw(translate);
use Words::DB::Config;
use Exporter qw(import);
use Try::Tiny;

our @EXPORT = qw(db_disconnect get_ID get_Z2A get_A2Z get_Time get_Count get_Delete splite_translation ui_translation db_get_a_store_word
     $insert_state $trans_state $fetch_state
     db_delete_store db_delete_delete);
our @EXPORT_OK = qw(cmd_translation);

my $dsn = 'dbi:mysql:database=wordstore;host=localhost;port:3306';
my $user = read_key('user');
my $passwd = read_key('passwd');

my $database = 'wordstore';
my $store_table = 'words';
my $delete_table = 'deleted';
my @columns = ("Query", "Phonetic", "Definitions", "Count");
my $primary_key = "ID";
my $timestamp_col = 'ts';
my $tmp_file = '/tmp/word_store_tmp';

# Connect to the database, get the database handle
my $dbh = DBI->connect($dsn, $user, $passwd,
            { RaiseError => 1, AutoCommit => 0 }) or die $DBI::errstr;

# output the trace message to a log file
my $dbitrace_file = '/tmp/dbitrace.log';
unlink $dbitrace_file if -e $dbitrace_file;
$dbh->trace( 3, $dbitrace_file );

# need to determine which handle will be used multiple time

my $sth_insert_store = $dbh->prepare( 
    sprintf "INSERT INTO %s(%s) VALUES(%s);",
    $store_table, join(',', @columns), join(', ', ("?") x @columns)
);
my $sth_insert_delete = $dbh->prepare( 
    sprintf "INSERT INTO %s(%s) VALUES(%s);",
    $delete_table, join(',', @columns), join(', ', ("?") x @columns)
);
my $sth_fetchall_store = $dbh->prepare(
    sprintf "SELECT * FROM %s;",
    $store_table
);
my $sth_fetchall_delete = $dbh->prepare(
    sprintf "SELECT * FROM %s ORDER BY %s DESC;",
    $delete_table, $timestamp_col
);
my $sth_fetchone_store = $dbh->prepare(
    sprintf "SELECT * FROM %s WHERE %s=?;",
    $store_table, $columns[0]
);
my $sth_fetch_ID = $dbh->prepare(
    sprintf "SELECT * FROM %s ORDER BY %s ASC;",
    $store_table, $primary_key
);
my $sth_fetch_Time = $dbh->prepare(
    sprintf "SELECT * FROM %s ORDER BY %s DESC;",
    $store_table, $timestamp_col
);
my $sth_fetch_Count = $dbh->prepare(
    sprintf "SELECT * FROM %s ORDER BY %s DESC;",
    $store_table, $columns[-1]
);
my $sth_fetch_A2Z = $dbh->prepare(
    sprintf "SELECT * FROM %s ORDER BY %s ASC;",
    $store_table, $columns[0]
);
my $sth_fetch_Z2A = $dbh->prepare(
    sprintf "SELECT * FROM %s ORDER BY %s DESC;",
    $store_table, $columns[0]
);

#####
######## Check exist
#####

my $sth_check_store_exist = $dbh->prepare(
    sprintf "SELECT %s FROM %s where %s = ?;",
    $columns[0], $store_table, $columns[0]
);
my $sth_check_delete_exist = $dbh->prepare(
    sprintf "SELECT %s FROM %s where %s = ?;",
    $columns[0], $delete_table, $columns[0]
);

#####
######## Update
#####

my $sth_update_store_count = $dbh->prepare(
    sprintf "UPDATE %s SET Count = Count + 1 WHERE %s = ?",
    $store_table, $columns[0]
);
my $sth_update_delete_count = $dbh->prepare(
    sprintf "UPDATE %s SET Count = Count + 1 WHERE %s = ?",
    $store_table, $columns[0]
);

#####
######## Delete
#####

my $sth_delete_store = $dbh->prepare(
    sprintf "DELETE FROM %s WHERE %s=?",
    $store_table, $columns[0]
);
my $sth_delete_delete = $dbh->prepare(
    sprintf "DELETE FROM %s WHERE %s=?",
    $delete_table, $columns[0]
);
#####
######## Used to update id
#####
my $sth_fetch_store_id = $dbh->prepare(
    sprintf "SELECT %s FROM %s ORDER BY %s ASC",
    $primary_key, $store_table, $primary_key
);
my $sth_update_store_id = $dbh->prepare(
    sprintf "UPDATE %s SET %s=? WHERE %s=?",
    $store_table, $primary_key, $primary_key
);
my $sth_fetch_delete_id = $dbh->prepare(
    sprintf "SELECT %s FROM %s ORDER BY %s ASC",
    $primary_key, $delete_table, $primary_key
);
my $sth_update_delete_id = $dbh->prepare(
    sprintf "UPDATE %s SET %s=? WHERE %s=?",
    $store_table, $primary_key, $primary_key
);

#####
######## State variables
#####
our $insert_state = 1;
our $trans_state  = 1;
our $fetch_state  = 1;

create_table($store_table);
create_table($delete_table);
# delete_table($store_table);
# delete_table($delete_table);
# set_utf8($store_table);
# set_utf8($delete_table);
# translation();
# show_tables();
# show_databases();
# sort_word();
# count_word();
# db_delete_store('list');
# $dbh->do("ALTER TABLE $store_table AUTO_INCREMENT = 1");
# db_update_id();
# db_get_all_words($sth_fetchall_store);
# db_get_all_words($sth_fetchall_delete);
# db_get_a_word($sth_fetchone, 'process');
# my @data_set = ();
# set_ID(\@data_set);
# print Dumper(db_get_a_store_word('test'));
# cmd_translation();
# ui_translation('test');
# db_disconnect();

sub cmd_translation {
    my $query = '';

    say   "\e[1mTranslate here\e[0m";
    say   "(:q to quit)";

    while (1) {
        print "\n\e[1m>\e[0m ";
        my $query = <STDIN>;
        exit unless defined $query;
        chomp($query);
        last if $query =~ /^:q$/;
        next if $query =~ /(?: )|(?:\n)|(:?^$)/;
        # if ($query =~ /:sort/) {sort_word(); next;}

        my ($result, $state) = translate($query);
        my $definitions_ref = splite_translation($result->{definitions});
        my $cowsay_str = `cowsay $query`;

        $trans_state = $state;
        if ($state == 1) {
            db_insert_store($result);
            printf("Definitions of [%s]\n", $query);
            printf("[ en -> en ]\n");
            printf("%s", $cowsay_str);
            printf("\n");
            foreach (@{$definitions_ref}) {
                my @def_and_example = split(/example:/, $_);
                printf(">>> %s\n", $def_and_example[0]);
                printf("    %s\n", $def_and_example[1] // "none");
                printf("\n");
                printf("\n");
            }
        }
        else {
            warn "Wrong with [translation] part";
        }
    }
}

sub ui_translation {
    my $query = shift;
    my ($result, $state) = translate($query);
    $trans_state = $state;

    if ($state == 1) {
        db_insert_store($result);
    }
    return $result;
}

sub db_disconnect {
    $dbh->disconnect();
}

# Check if the table "words" exists
# not then create the table
# existes then jump
sub create_table {
    my $table = shift;

    my $tables = get_tables();    return if grep /^\Q$table\E$/, @{$tables};
    # if (grep /^\Q$table\E$/, @{$tables}) {
    #     warn "The table: [$table] already exists...";
    #     return;
    # }
    if ($dbh->do(
        sprintf "CREATE TABLE %s 
        (
            %s           INT          NOT NULL AUTO_INCREMENT,
            %s      VARCHAR(50 ) NOT NULL,
            %s      VARCHAR(50 ) NOT NULL,
            %s      VARCHAR(800) NOT NULL,
            %s      INT          NOT NULL,
            %s      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (%s)
        );
        ", $table, $primary_key, @columns, $timestamp_col, $primary_key)) 
    {
        print "Table $table created successfully.\n";
    }
    else {
        print "Failed to create table $table\n";
    }
}

sub get_tables {
    my $sth = $dbh->prepare("SHOW TABLES;");
    $sth->execute();
    my $tables_ref = $sth->fetchall_arrayref();
    my @tables = ();
    foreach (0..@{$tables_ref}-1) {
        push @tables, $tables_ref->[$_]->[0];
    }

    $sth->finish();
    return \@tables;
}

# the $data is a hash ref
sub db_insert_store {
    die "The variable passing to 'insert' is not a hash ref" 
        unless ref $_[0] eq ref {};

    my $data = shift;

    # check the first column of table, if exist, then update the count
    $sth_check_store_exist->execute($data->{query});
    if ( $sth_check_store_exist->rows > 0 ) {
        $sth_update_store_count->execute($data->{query});
    }
    else {
        try {
            $sth_insert_store->execute($data->{query}, $data->{phonetic}, $data->{definitions}, 1);
            $insert_state = 1;
        } catch {
            $insert_state = 0;
        };
    }

    $sth_check_store_exist->finish();
    $sth_update_store_count->finish();
    $sth_insert_store->finish();

    $dbh->commit();
}

sub db_insert_delete {
    die "The variable passing to 'insert' is not a hash ref" 
        unless ref $_[0] eq ref {};

    my $data = shift;

    # check the first column of table, if exist, then update the count
    $sth_check_delete_exist->execute($data->{query});
    if ( $sth_check_delete_exist->rows > 0 ) {
        $sth_update_delete_count->execute($data->{query});
    }
    else {
        try {
            $sth_insert_delete->execute($data->{query}, $data->{phonetic} // "none", $data->{definitions}, 1);
            $insert_state = 1;
        } catch {
            $insert_state = 0;
        };
    }

    $sth_check_delete_exist->finish();
    $sth_update_delete_count->finish();
    $sth_insert_delete->finish();

    $dbh->commit();
}

sub db_delete_store {
    my $word = shift;

    my $word_info = db_get_a_store_word($word);
    if ( $fetch_state == 1 ) {
        db_insert_delete($word_info->[0]);
        $sth_delete_store->execute($word);

        db_update_id($store_table, $sth_fetch_store_id, $sth_update_store_id);

        $sth_delete_store->finish();
        $dbh->commit();
    }
    else {
        warn "The word [$word] is not in the database";
    }

}

sub db_delete_delete {
    my $word = shift;

    $sth_delete_delete->execute($word);

    db_update_id($delete_table, $sth_fetch_delete_id, $sth_update_delete_id);

    $sth_delete_store->finish();
    $dbh->commit();
}

sub db_update_id {
    my $table      = shift;
    my $sth_fetch  = shift;
    my $sth_update = shift;

    $sth_fetch->execute();
    my $max_id = $sth_fetch->rows;

    # 更新 ID 字段
    my $i = 1;
    while (my ($id) = $sth_fetch->fetchrow_array()) {
        $sth_update->execute($i, $id);
        $i++;
    }

    # 重置自增起始值
    $dbh->do("ALTER TABLE $table AUTO_INCREMENT = $max_id");

    $sth_fetch->finish();
    $sth_update->finish();
    $dbh->commit();
}

# there are several ways to list words:
#   1) alphabetically
#   2) count
#   3) random
#   4) ID, also time
#
sub sort_word {
    my $sth = $dbh->prepare(sprintf "SELECT %s from %s", $columns[0], $store_table);
    $sth->execute();
    #$sth->execute();
    
    my @words = ();
    while (my ($word) = $sth->fetchrow_array()) {
        push @words, $word;
    }
    @words = sort @words;
    print join("\n", @words);
    print "\n";

    $sth->finish();
}

sub count_word {
    my $sth = $dbh->prepare(sprintf "SELECT COUNT(*) FROM %s", $store_table);
    $sth->execute();

    my $count = $sth->fetchrow_array();
    print "The table [$store_table] contains $count words.\n";

    $sth->finish();
}

sub db_get_all_words {
    my $sth = shift;
    my @words = ();

    my @all_columns = @columns;
    unshift @all_columns, $primary_key;
    push @all_columns, $timestamp_col;
    $sth->execute();
    while(my @word_info = $sth->fetchrow_array()) {
        my %word = ();
        @word{map {lc $_} @all_columns} = @word_info;
        push @words, %word;
        db_print_word(\%word);
    }

    $sth->finish();

    return \@words;
}

sub db_get_a_store_word {
    my $word = shift;

    my $data_ref;
    $sth_fetchone_store->execute($word);
    if ( $sth_fetchone_store->rows > 0 ) {
        $data_ref = $sth_fetchone_store->fetchall_arrayref( {query => 1, definitions => 1, count => 1, ts => 1} );
        $fetch_state = 1;
    }
    else {
        $fetch_state = 0;
    }

    $sth_fetchone_store->finish();

    return $data_ref;
}

sub db_print_word {
    die "The variable passing to 'print_translation' is not a hash ref" 
        unless ref $_[0] eq ref {};

    my $word = shift;

    say "ID: $word->{lc $primary_key}";
    say "$word->{query}"; 
    # say "/$word->{Phonetic}/" if defined $word->{Phonetic};
    # say "";
    # say "[ \e[4m$columns[0]\e[0m -> \e[1m$columns[2]\e[0m ]";
    # say "";
    # say "example";
    # say "\e[1m    $word->{Example1}\e[0m";
    # say "       $word->{Translation1}";
    # say "";
    # say "\e[1m    $word->{Example2}\e[0m";
    # say "       $word->{Translation2}";
    # say "";
    # say "\e[4m$word->{query}\e[0m";
    # say "\e[1m   $word->{Chinese}\e[0m";
    # say "";
    # say "";

}

sub set_utf8 {
    my $table = shift;

    $dbh->do(sprintf("ALTER TABLE %s CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;", $table));
}

sub show_databases {
    my $sth = $dbh->prepare("SHOW DATABASES;");
    $sth->execute();
    while (my $row = $sth->fetchrow_arrayref()) {
        say $row->[0];
    }

    $sth->finish();
}

sub show_tables {
    my $sth = $dbh->prepare("SHOW TABLES;");
    $sth->execute();
    while (my $row = $sth->fetchrow_arrayref()) {
        say $row->[0];
    }

    $sth->finish();
}

sub delete_table {
    my $table = shift;

    if ($dbh->do(sprintf("DROP TABLE %s", $table))) {
        print "Table $table dropped successfully.\n";
    }
    else {
        print "Failed to drop table $table\n";
    }
}

# return data or set data
# create the array automatically

# if the array is 0, then return the array
# the ID part should like:
# ID(BEGIN:1, END:4 LEN = 4) word(LEN = 15)     translation(one speech LEN = 30)    count(3)     time(20) 
# 
# two mode: ascending, descending
sub get_ID {
    $sth_fetch_ID->execute();
    my $data_ref = $sth_fetch_ID->fetchall_arrayref( {id => 1, query => 1, definitions => 1, count => 1, ts => 1} );

    $sth_fetch_ID->finish();
    return $data_ref;
}

# the Time part should like:
# grouped by days (most recent comes first): 
# [day1]
# word1      translation         count
# word2      translation         count
#
# [day2]
# word3      translation         count
# word4      translation         count
# 
# two mode: ascending, descending
sub get_Time {
    $sth_fetch_Time->execute();
    my $data_ref = $sth_fetch_Time->fetchall_arrayref( {query => 1, count => 1, ts => 1} );

    $sth_fetch_Time->finish();
    return $data_ref;
}


# the Count part should like:
# count     word     translation 
# 
# two mode: ascending, descending
sub get_Count {
    $sth_fetch_Count->execute();
    my $data_ref = $sth_fetch_Count->fetchall_arrayref( {query => 1, count => 1, ts => 1} );

    $sth_fetch_Count->finish();
    return $data_ref;
}

# the A2Z part should like:
# [A]
# word     translation 
# .
# .
# [Z]
# word     translation 
#
# Jump to a letter
sub get_A2Z {
    $sth_fetch_A2Z->execute();
    my $data_ref = $sth_fetch_A2Z->fetchall_arrayref( {query => 1, count => 1, ts => 1} );

    $sth_fetch_A2Z->finish();
    return $data_ref;
}

# the Z2A part should like:
# [Z]
# word     translation 
# .
# .
# [A]
# word     translation 
#
# Jump to a letter
sub get_Z2A {
    $sth_fetch_Z2A->execute();
    my $data_ref = $sth_fetch_Z2A->fetchall_arrayref( {query => 1, count => 1, ts => 1} );

    $sth_fetch_Z2A->finish();
    return $data_ref;
}

# the Curve part should like:
# use number to draw curve, with X-axis and Y-axis
# 
# two mode: time, count
#
# sub return_Curve_part {
#     
# }

# the Delete part should like:
# ID(BEGIN:1, END:4 LEN = 4) word(LEN = 15)     translation(one speech LEN = 30)    count(3)     time(20) 
# 
# two mode: ascending, descending
sub get_Delete {
    $sth_fetchall_delete->execute();
    my $data_ref = $sth_fetchall_delete->fetchall_arrayref( {query => 1, definitions => 1, ts => 1} );

    $sth_fetchall_delete->finish();
    return $data_ref;
}


# should determine whether a entry is a word or sentence, create a table for sentence
# change the function of print_page, it will receive an array and print to a page
#
# get all words at the beginning, and handle by Perl
#
# get part of words handle by DB
sub splite_translation {
    my $translation = shift;

    my @splited_trans = split /;;/, $translation;

    return \@splited_trans;
}

1;
