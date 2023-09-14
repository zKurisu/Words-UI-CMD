# ABSTRACT: turns baubles into trinkets
package Words::UI::CMD;

use warnings;
use strict;
use Curses;
use Curses::UI;
use Chart::Gnuplot;
use File::Slurper 'read_text';
use Words::DB::Handler;

my $cui = Curses::UI->new(
    -clear_on_exit => 0,
    -color_support => 1,
    # -debug         => 1,
);

my @menu_list  = qw(Translate Time ID Count A-Z Z-A Delete Curve Game);

my $win_width  = 15;
my $win_height = 5;

my $menu_begin_y = 1;
my $menu_begin_x = 1;
my $menu_width   = 12;
my $menu_height  = $cui->height();

my $spacer       = 3;

my $body_begin_y = 1;
my $body_begin_x = $menu_width + $spacer;
my $body_width   = $cui->width() - $menu_width - $spacer;
my $body_height  = $cui->height();

my $help_label_begin_x = $body_begin_x + 10;
my $help_label_begin_y = 0;

my $help_viewer_width = 2/3 * $cui->width();
my $help_viewer_height = 2/3 * $cui->height();
my $help_viewer_begin_x = ($cui->width()-$help_viewer_width)/2;
my $help_viewer_begin_y = ($cui->height()-$help_viewer_height)/2;

my $debug_begin_x = 20;
my $debug_begin_y = 20;

# Dialog
# my $dialog_width  = 20;
# my $dialog_height = 10;
# my $dialog_begin_x = ($cui->width()-$dialog_width)/2;
# my $dialog_begin_y = ($cui->height()-$dialog_height)/2;

# relative to translation window
my $trans_begin_x = 0;
my $trans_begin_y = 3;

my $splite_width = $body_width - 10;

my $greet_message = "
 _   _      _ _         ___        __            _     _
| | | | ___| | | ___   ( ) \\      / /__  _ __ __| |___( )
| |_| |/ _ \\ | |/ _ \\  |/ \\ \\ /\\ / / _ \\| '__/ _` / __|/
|  _  |  __/ | | (_) |     \\ V  V / (_) | | | (_| \\__ \\
|_| |_|\\___|_|_|\\___/       \\_/\\_/ \\___/|_|  \\__,_|___/
";
my @greet_array = split("\n", $greet_message);

my $game_greet = "
 __  __       _       _       _____ _           __        __            _
|  \/  | __ _| |_ ___| |__   |_   _| |__   ___  \ \      / /__  _ __ __| |___
| |\/| |/ _` | __/ __| '_ \    | | | '_ \ / _ \  \ \ /\ / / _ \| '__/ _` / __|
| |  | | (_| | || (__| | | |   | | | | | |  __/   \ V  V / (_) | | | (_| \__ \
|_|  |_|\__,_|\__\___|_| |_|   |_| |_| |_|\___|    \_/\_/ \___/|_|  \__,_|___/
";
my @game_array = split("\n", $game_greet);

my $help_message = qq(
# Default Keybindings

Keybindings:
    
    Esc:            - Exit current action
    <C-q>:          - Exit the program
    h:              - Back to last section
    j:              - Move down
    k:              - Move up
    l:              - Open detail
    g:              - Go to top
    G:              - Go to bottom
     
);

my $plot_file = '/tmp/plotfile';

#####
######## Main
#####
#
my $win_main = $cui->add(
    'main window', 'Window',
    -wrapping => 1,
);
my $help_label = $win_main->add(
    'help lable', 'Label',
    -text => '^q:Quit   h:Back to word list   j:Scroll down   k:scroll up   l:detail info   ?:Help',
    -x    => $help_label_begin_x,
    '-y'  => $help_label_begin_y,
);
my $debug_label = $win_main->add(
    'debug lable', 'Label',
    -text => "                                                       ",
    # -x    => $debug_begin_x,
    # '-y'  => $debug_begin_y,
    -x    => 0,
    '-y'  => 0,
);
my $dialog_main = $win_main->add(
    'dialog main', 'Dialog::Basic',
    -message => "Do you want to delete this word",
    -buttons   => [ 'yes', 'no' ],
);
my $textviewer_main = $win_main->add(
    'help viewer', 'TextViewer',
    -title  => "Help",
    -border => 1,
    -width  => $help_viewer_width,
    -height => $help_viewer_height,
    -x      => $help_viewer_begin_x,
    '-y'    => $help_viewer_begin_y
);

#####
######## Menu
#####

my $win_menu = $win_main->add(
    'menu window', 'Window',
    -title => 'Menu',
    -width => $menu_width,
    -height => $menu_height,
    -border => 1,
    -wrapping => 1,
    -x => $menu_begin_x,
    '-y' => $menu_begin_y,
);
my $listbox_menu = $win_menu->add(
    'listbox menu', 'Listbox',
    -values => \@menu_list,
    -selected => 0,
    # -height => scalar(@menu_list) + 2,
    # -width  => 20,
    -onchange => \&menu_change,
);

#####
######## Body
#####

my $win_body = $win_main->add(
    'body window', 'Window',
    -title => 'Body',
    -width => $body_width,
    -height => $body_height,
    -border => 1,
    -wrapping => 1,
    -x => $body_begin_x,
    '-y' => $body_begin_y,
);
my $listbox_body = $win_body->add(
    'listbox body', 'Listbox',
    -wrapping => 1,
    # -values => \@test_array,
    # -onchange => \&debug,
    # -onselchange => 
);
my $textviewer_body = $win_body->add(
    'curve viewer', 'TextViewer',
);

#####
######## Detail
#####

my $win_detail = $win_main->add(
    'detail window', 'Window',
    -title => 'Detail',
    -width => $body_width,
    -height => $body_height,
    -border => 1,
    -wrapping => 1,
    -x => $body_begin_x,
    '-y' => $body_begin_y,
);
my $listbox_detail = $win_detail->add(
    'detail listbox', 'Listbox',
    -wrapping => 1,
);

#####
######## Trans
#####

my $win_trans = $win_main->add(
    'translation window', 'Window',
    -title => 'Translation',
    -width => $body_width,
    -height => $body_height,
    -border => 1,
    -wrapping => 1,
    -x => $body_begin_x,
    '-y' => $body_begin_y,
);
my $textentry_word = $win_trans->add(
    'textentry word', 'TextEntry',
    -border => 1,
);
my $listbox_trans  = $win_trans->add(
    'translation listbox', 'Listbox',
    -border => 1,
    -values => \@greet_array,
    -x      => $trans_begin_x,
    '-y'    => $trans_begin_y,
    -wrapping => 1,
);


main_ui();

sub main_ui {
    move_contrl();

    $cui->mainloop();
}

sub exit_handle {
    db_disconnect();
    $cui->mainloopExit();
}

sub move_contrl {
    # 添加 Ctrl+Q 键事件处理程序，使用该键退出应用程序
    $cui->set_binding( \&exit_handle, "\cq" );

    # 显示窗口直到用户按下 Ctrl+Q 键退出
    $listbox_menu->focus();
    $textentry_word->focus();
    #$textviewer_main->focus();

    #####
    ######## Main
    #####
    $win_main->set_binding( sub {
        $textviewer_main->focus();
        $textviewer_main->text($help_message);
    }, "?" );
    $textviewer_main->set_binding( sub {
        my $current_menu = $listbox_menu->get();
        if ( $current_menu eq 'Translate') {
            $textentry_word->focus();
        }
        else {
            $listbox_body->focus();
        }
    }, "\e");

    #####
    ######## body
    ##### 
    $listbox_body->set_binding( sub {
        $listbox_body->process_bindings(KEY_ENTER);
        my $word = return_word();
        my $result = db_get_a_store_word($word);
        if ($fetch_state == 1) {
            my $definitions = splite_translation($result->[0]->{definitions});
            my @data   = ();
            push @data, sprintf("Definitions of [%s]", $result->[0]->{query});
            push @data, sprintf("[ en -> en ]");
            push @data, sprintf("\n");
            foreach (@{$definitions}) {
                my @def_and_example = split(/example:/, $_);
                my @substrings = ($def_and_example[0] =~ /.{1,$splite_width}/g);
                push @data, sprintf(">>> %s", $substrings[0]);
                foreach (1..@substrings-1) {
                    push @data, sprintf("    %s", $substrings[$_] // "none");
                }
                push @data, sprintf("    %s", $def_and_example[1] // "none");
                push @data, sprintf("\n");
                push @data, sprintf("\n");
            }
            $listbox_detail->focus();
            $listbox_detail->values(\@data);
            $listbox_detail->draw;
        }
    }, "l" );
    $listbox_body->set_binding( sub { $listbox_menu->focus(); }, "h" );
    $listbox_body->set_binding( sub { 
        if (defined $listbox_body->get()) {
            $dialog_main->focus(); 
        }
        else {
            $cui->error("Please select a word");
        }
    }, "d" );
    $dialog_main->set_binding(  sub {
        if ( $dialog_main->get() == 1 ) {
            # delete the word first
            if ( $listbox_menu->get() eq 'Delete' ) {
                db_delete_delete(return_word());
            }
            else {
                db_delete_store(return_word());
            }
            $listbox_menu->process_bindings("l");
            $listbox_body->focus();
        } 
        else {
            $listbox_body->focus();
        }

    }, KEY_ENTER );
    $listbox_body->set_binding( sub {
        $listbox_body->process_bindings("\ca");
    }, "g" );
    $listbox_body->set_binding( sub {
        $listbox_body->process_bindings("\ce");
    }, "G" );
    $textviewer_body->set_binding( sub { $listbox_menu->focus() }, "h" );

    #####
    ######## Detail
    #####
    $listbox_detail->set_binding( sub { $listbox_body->focus() }, "h" );

    #####
    ######## Menu
    #####
    $listbox_menu->set_binding( sub {
        $listbox_menu->process_bindings(KEY_ENTER);
        menu_change();
    }, "l" );
    $listbox_menu->set_binding( sub {
        $listbox_menu->process_bindings("\ca");
    }, "g" );
    $listbox_menu->set_binding( sub {
        $listbox_menu->process_bindings("\ce");
    }, "G" );

    #####
    ######## Translation
    ##### 
    $textentry_word->set_binding( sub { $listbox_menu->focus() }, "\e" );
    $textentry_word->set_binding( sub {
        my $word   = $textentry_word->get();
        my $cowsay_str = `cowsay $word`;
        my @cowsay_array = split("\n", $cowsay_str);
        $textentry_word->text("waitting....");
        $textentry_word->draw();
        my $result = ui_translation($word);
        if ($trans_state == 0) {
            $cui->error("Something wrong in [Translation] part");
            $textentry_word->text("");
        } 
        elsif ($insert_state == 0) {
            $cui->error("Something wrong in [Insert] part");
            $textentry_word->text("");
        }
        else {
            my $definitions = splite_translation($result->{definitions});
            my @data   = ();
            foreach (@cowsay_array) {
                push @data, $_;
            }
            push @data, sprintf("\n");
            push @data, sprintf("\n");
            push @data, sprintf("Definitions of [%s]", $result->{query});
            push @data, sprintf("[ en -> en ]");
            push @data, sprintf("\n");
            foreach (@{$definitions}) {
                my @def_and_example = split(/example:/, $_);
                my @substrings = ($def_and_example[0] =~ /.{1,$splite_width}/g);
                push @data, sprintf(">>> %s", $substrings[0]);
                foreach (1..@substrings-1) {
                    push @data, sprintf("    %s", $substrings[$_] // "none");
                }
                push @data, sprintf("    %s", $def_and_example[1] // "none");
                push @data, sprintf("\n");
                push @data, sprintf("\n");
            }
            $listbox_trans->values(\@data);
            $listbox_trans->draw();
            $textentry_word->text("");
        }
    }, KEY_ENTER );
}

sub menu_change {
    my $current_menu = $listbox_menu->get();
    if ( $current_menu eq 'Translate') {
        $textentry_word->focus();
    }
    elsif ( $current_menu eq 'ID' ) {
        $listbox_body->focus();

        my $data_ref = get_ID();
        my @data = ();
        foreach (@{$data_ref}) {
            push @data, sprintf("%-4s%-15s%4s%20s", $_->{id}, $_->{query}, $_->{count}, $_->{ts});
        }
        $listbox_body->values(\@data);
        $listbox_body->draw();
    }
    elsif ( $current_menu eq 'Time' ) {
        $listbox_body->focus();

        my $data_ref = get_Time();
        my @data     = ();
        my $count    = 1;
        foreach (@{$data_ref}) {
            my ($date) = $_->{ts} =~ m/(\d+-\d+-\d+)/;
            unless ( grep /\Q$date\E/, @data ) {
                push @data, sprintf("\n");
                push @data, "[$date]";
                $count = 1;
            }
            else {
                $count++;
            }
            push @data, sprintf("%-4s%-15s%4s", $count, $_->{query}, $_->{count});
        }
        # remove the first newline
        shift @data;
        $listbox_body->values(\@data);
        $listbox_body->draw();
    }
    elsif ( $current_menu eq 'Count' ) {
        $listbox_body->focus();

        my $data_ref = get_Count();
        my @data     = ();
        my $count    = 1;
        foreach (@{$data_ref}) {
            push @data, sprintf("%-4s%-15s%4s", $count, $_->{query}, $_->{count});
            $count++;
        }
        # remove the first newline
        $listbox_body->values(\@data);
        $listbox_body->draw();
    }
    elsif ( $current_menu eq 'A-Z' ) {
        $listbox_body->focus();

        my $data_ref = get_A2Z();
        my @data     = ();
        my $count    = 1;
        foreach (@{$data_ref}) {
            my $first_letter = sprintf("[%s]", substr($_->{query}, 0, 1));
            unless ( grep /\Q$first_letter\E/, @data ) {
                push @data, sprintf("\n");
                push @data, $first_letter;
                $count = 1;
            }
            else {
                $count++;
            }
            push @data, sprintf("%-4s%-15s%4s", $count, $_->{query}, $_->{count});
        }
        # remove the first newline
        shift @data;
        $listbox_body->values(\@data);
        $listbox_body->draw();
    }
    elsif ( $current_menu eq 'Z-A' ) {
        $listbox_body->focus();

        my $data_ref = get_Z2A();
        my @data     = ();
        my $count    = 1;
        foreach (@{$data_ref}) {
            my $first_letter = sprintf("[%s]", substr($_->{query}, 0, 1));
            unless ( grep /\Q$first_letter\E/, @data ) {
                push @data, sprintf("\n");
                push @data, $first_letter;
                $count = 1;
            }
            else {
                $count++;
            }
            push @data, sprintf("%-4s%-15s%4s", $count, $_->{query}, $_->{count});
        }
        # remove the first newline
        shift @data;
        $listbox_body->values(\@data);
        $listbox_body->draw();
    }
    elsif ( $current_menu eq 'Delete' ) {
        #$cui->error("You have not finish this part");
        $listbox_body->focus();

        my $data_ref = get_Delete();
        my @data     = ();
        my $count    = 1;
        foreach (@{$data_ref}) {
            my ($date) = $_->{ts} =~ m/(\d+-\d+-\d+)/;
            unless ( grep /\Q$date\E/, @data ) {
                push @data, sprintf("\n");
                push @data, "[$date]";
                $count = 1;
            }
            else {
                $count++;
            }
            push @data, sprintf("%-4s%-15s", $count, $_->{query});
        }
        # remove the first newline
        shift @data;
        $listbox_body->values(\@data);
        $listbox_body->draw();
    }
    elsif ( $current_menu eq 'Curve' ) {
        $listbox_body->focus();

        my $data_ref   = get_Time();
        my @date_x     = ();
        my @count_y    = ();
        my $count      = 1;
        foreach (@{$data_ref}) {
            my ($date) = $_->{ts} =~ m/(\d+-\d+-\d+)/;
            unless ( grep /\Q$date\E/, @date_x ) {
                push @date_x, $date;
                push @count_y, $count;
                $count = 1;
            }
            else {
                $count++;
            }
        }
        push @count_y, $count;
        # remove the first newline
        shift @count_y;
        draw_curve(\@date_x, \@count_y);
        my $curve = read_text($plot_file);
        $textviewer_body->text($curve);
        $textviewer_body->focus();
    }
}

sub debug {
    my $text = shift;
    $debug_label->text(sprintf("%s", $text));
    $cui->layout();
    $cui->draw();
}

sub return_word {
    my $entry  = $listbox_body->get();
    my ($word) = $entry =~ m/\d+\s+(\w+)/;
    return $word;
}

sub draw_curve {
    my $x_ref = shift;
    my $y_ref = shift;

    # Create the chart object
    my $chart = Chart::Gnuplot->new(
        output   => $plot_file,
        terminal => 'dumb',
        xlabel   => 'Date axis',
        timeaxis => "x",    # x-axis uses time format
    );

    # Data set object
    my $data = Chart::Gnuplot::DataSet->new(
        xdata   => $x_ref,
        ydata   => $y_ref,
        style   => 'linespoints',
        timefmt => '%Y-%m-%d',      # input time format
    );

    # 输出图表
    eval {$chart->plot2d($data)};
    if ($@) {
        debug($@);
    }
}

1;
