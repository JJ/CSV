#!perl6

use v6;
use Slang::Tuxic;

use Test;
use Text::CSV;

my $csv    = Text::CSV.new;

my $fni    = "_90in.csv";
my $fno    = "_90out.csv";
END { unlink $fni, $fno; }


my Str @hdr  = < bar baz foo >;
my Str $hdr  = @hdr.join (",");
my Str @data = $hdr, "1,2,3", "2,a b,";
my Str $data = @data.map (*~"\r\n").join ("");
my @expect   = @data.map ({[ $_.split (",") ]});

{   my $fh = open $fni, :w;
    $fh.say ($_) for @data;
    $fh.close;
    }

my $io-in  = open $fni, :r;
my $io-out = open $fno, :w;

sub provider {
    state Str @dta = @data;
    if (@dta.elems == 0) {
        @dta = @data;
        return False;
        }
    [ @dta.shift.split (",") ];
    }

my $full-aoa = [[@hdr],["1","2","3"],["2","a b",""]];
my $full-aoh = [{:bar("1"),:baz("2"),:foo("3")},{:bar("2"),:baz("a b"),:foo("")}];
# Rebuild an expect array for shuffled hash keys
my @h-expect;
for 0 .. 2 -> $i {
    my Str $k = $full-aoh[0].keys[$i];
    @h-expect[0][$i] = $k;
    @h-expect[1][$i] = $full-aoh[0]{$k};
    @h-expect[2][$i] = $full-aoh[1]{$k};
    }

my @in =
    $fni,                       # Str
    $io-in,                     # IO::Handle
   \($data),                    # Capture
    [$data],                    # Array of String
    [@data],                    # Array of Strings
    $full-aoa,                  # Array of Array
    $full-aoh,                  # Array of Hash

    &provider,                  # Sub
    {                           # Callable/Block
        state Str @dta = @data; # (cannot have return's)
        if (@dta.elems == 0) {
            @dta = @data;
            False;
            }
        else {
            [ @dta.shift.split (",") ];
            }
        },
    # Supply push later         # Supply
    # Channel push later        # Channel
    ;

sub sleep-time {
    state $sleep;

    defined $sleep and return $sleep;
    $sleep = do {
        my $start = now;
        for 1 .. 10000 -> $n { my $y = $n * ($n - 1) + ($n - 1) / $n; }
        (max 0.7, now - $start).round (0.01);
        };
    }

sub in {
    my @i = @in;
    @i.push: Supply.from-list (@data);
    my $ch = Channel.new;
    start {
        $ch.send ($_) for @data;
        $ch.close;
        }
    @i.push: $ch;
    @i;
    }

sub s-in (Any $in) {
    my Str $type = $in.WHAT.gist;
    if ($in ~~ Array && $in.elems > 0) {
        $type ~= $in.list[0].WHAT.gist;
        $type ~~ s{")("} = " of ";
        }
    my Str $s-in = sprintf "%-16s %s", $type, $in.gist;
    $s-in ~~ s:g{\n} = "\\n";
    $s-in;
    }

sub inok ($in, @r, Str $diag) {
    ok (@r, $diag); # Expect Array.new (["a", "b"], ["1", "2"], ["3", "4"])
    #@r.perl.say;
    $io-in.seek (0, SeekFromBeginning);
    is (@r.elems, 3, "AoX should have 3 rows");
    if ($in ~~ Array && $in[0] ~~ Hash) {
        is-deeply (@r, @h-expect, "Content");
        }
    else {
        is-deeply (@r,   @expect, "Content");
        }
    }

# Test supported "in" formats for all scopes
for in () -> $in {
    inok ($in, Text::CSV.csv (in => $in, meta => False), "Class   { s-in ($in) }");
    }
for in () -> $in {
    inok ($in,      $csv.csv (in => $in, meta => False), "Method  { s-in ($in) }");
    }
for in () -> $in {
    inok ($in,           csv (in => $in, meta => False), "Sub     { s-in ($in) }");
    }
for in () -> $in {
    inok ($in,           csv (in => $in, csv  => $csv),  "Sub/Obj { s-in ($in) }");
    }

# Test supported "out" formats
my $datn = $data; $datn ~~ s:g{ "\r\n" } = "\n";
for in () -> $in {
    # lizmat: fix jij deze: ?
#   is (csv (in => $in, out => Str, :!quote-space), $data|$datn, "csv => Str   { s-in ($in) }");
    }

is (csv (in => $fni, out => Str, fragment => "row=2"),    "1,2,3\r\n"       |"1,2,3\n",    "Fragment, row");
is (csv (in => $fni, out => Str, fragment => "col=3"),    "foo\r\n3\r\n\r\n"|"foo\n3\n\n", "Fragment, col");
is (csv (in => $fni, out => Str, fragment => "cell=1,1"), "bar\r\n"         |"bar\n",      "Fragment, cell");

$io-in.seek (0, SeekFromBeginning);
for in () -> $in {
    if ($in ~~ Array && $in[0] ~~ Hash) {
        is-deeply (csv (in => $in, out => Array), [@h-expect], "csv => Array { s-in ($in) }");
        }
    else {
        is-deeply (csv (in => $in, out => Array),  $full-aoa , "csv => Array { s-in ($in) }");
        }
    }

$io-in.seek (0, SeekFromBeginning);
for in () -> $in {
    is-deeply (csv (in => $in, out => Hash),  $full-aoh, "csv => Hash  { s-in ($in) }");
    }

$io-in.seek (0, SeekFromBeginning);
for in () -> $in {
    ok (my $csv = Text::CSV.new, "new for Hash + skip");
    ok ($csv.column_names (@hdr), "colnames");
    if ($in ~~ Array && $in[0] ~~ Hash) {
        my Str @h = $full-aoh[0].keys;
        is-deeply ($csv.CSV (in => $in, out => Hash, skip => 1, headers => [@h]),
            $full-aoh, "csv => Hash + skip { s-in ($in) }");
        }
    else {
        is-deeply ($csv.CSV (in => $in, out => Hash, skip => 1),
            $full-aoh, "csv => Hash + skip { s-in ($in) }");
        }
    }

$io-in.seek (0, SeekFromBeginning);
for in () -> $in {
    ok (my $csv = Text::CSV.new, "new for Hash + auto");
    is-deeply ([$csv.csv (in => $in, headers => "auto")],
        $full-aoh, "csv => Hash + auto { s-in ($in) }");
    }

$io-in.seek (0, SeekFromBeginning);
for in () -> $in {
    ok (my $csv = Text::CSV.new, "new for Block");
    my @d;
    $csv.CSV (in => $in, out => { @d.push: $_ }, :!meta);
    if ($in ~~ Array && $in[0] ~~ Hash) {
        is-deeply ( @d , @h-expect, "csv => Block { s-in ($in) }");
        }
    else {
        is-deeply ([@d], $full-aoa, "csv => Block { s-in ($in) }");
        }
    }

$io-in.seek (0, SeekFromBeginning);
for in () -> $in {
    my @d;
    Text::CSV.csv (in => $in, out => { @d.push: $_ }, headers => "auto", :!meta);
    is-deeply ([@d], $full-aoh, "csv => Block { s-in ($in) }");
    }

$io-in.seek (0, SeekFromBeginning);
for in () -> $in {
    ok (my $csv = Text::CSV.new, "new for Channel");
    my @d;
    my $ch = Channel.new;
    my $thr = start {
        react {
            whenever $ch -> \row {
                @d.push: row;
                LAST { done; }
                }
            }
        }
    $csv.CSV (in => $in, out => $ch, :!meta);
    print ""; # Needed for await synchronization. Herd to reproduce bug?
    await $thr;
    if ($in ~~ Array && $in[0] ~~ Hash) {
        is-deeply ( @d , @h-expect, "csv => Channel { s-in ($in) }");
        }
    else {
        is-deeply ([@d], $full-aoa, "csv => Channel { s-in ($in) }");
        }
    }

$io-in.seek (0, SeekFromBeginning);
for in () -> $in {
    ok (my $csv = Text::CSV.new, "new for Channel");
    my @d;
    my $ch = $csv.CSV (in => $in, out => Channel, :!meta);
    react {
        whenever $ch -> \row {
            @d.push: row;
            LAST { done; }
            }
        }
    if ($in ~~ Array && $in[0] ~~ Hash) {
        is-deeply ( @d , @h-expect, "csv => Channel { s-in ($in) }");
        }
    else {
        is-deeply ([@d], $full-aoa, "csv => Channel { s-in ($in) }");
        }
    }

$io-in.seek (0, SeekFromBeginning);
for in () -> $in {
    ok (my $csv = Text::CSV.new, "new for Channel + Hash");
    my @d;
    my $ch = $csv.CSV (in => $in, out => Channel, headers => "auto", :!meta);
    react {
        whenever $ch -> \row {
            @d.push: row;
            LAST { done; }
            }
        }
    is-deeply ([@d], $full-aoh, "csv => Channel { s-in ($in) }");
    }

$io-in.seek (0, SeekFromBeginning);
for in () -> $in {
    ok (my $csv = Text::CSV.new, "new for Supplier");
    my @d;
    my $ch = Supplier.new;
    $ch.Supply.tap (-> \row { @d.push: row; });
    $csv.CSV (in => $in, out => $ch, :!meta);
    if ($in ~~ Array && $in[0] ~~ Hash) {
        is-deeply ( @d , @h-expect, "csv => Supplier { s-in ($in) }");
        }
    else {
        is-deeply ([@d], $full-aoa, "csv => Supplier { s-in ($in) }");
        }
    }

$io-in.seek (0, SeekFromBeginning);
for in () -> $in {
    ok (my $csv = Text::CSV.new, "new for Supply");
    my @d;
    my $ch = $csv.CSV (in => $in, out => Supply, :!meta);
    $ch.tap (-> \row { @d.push: row; });
    if ($in ~~ Array && $in[0] ~~ Hash) {
        is-deeply ( @d , @h-expect, "csv => Supplier { s-in ($in) }");
        }
    else {
        is-deeply ([@d], $full-aoa, "csv => Supplier { s-in ($in) }");
        }
    }

$io-in.seek (0, SeekFromBeginning);
for in () -> $in {
    ok (my $csv = Text::CSV.new, "new for Supply + Hash");
    my @d;
    my $ch = $csv.CSV (in => $in, out => Supply, :!meta, headers => "auto");
    $ch.tap (-> \row { @d.push: row; });
    is-deeply ([@d], $full-aoh, "csv => Supplier { s-in ($in) }");
    }

# Additional attributes like headers and fragment

$io-in.seek (0, SeekFromBeginning);
for in () -> $in {
    ok (my $csv = Text::CSV.new, "new for Hash + hdrs");
    if ($in ~~ Array && $in[0] ~~ Hash) {
        my Str @h = $full-aoh[0].keys;
        is-deeply ($csv.csv (in => $in, headers => [@h  ], frag => "row=2-*"),
            $full-aoh, "csv => Hash + hdrs { s-in ($in) }");
        }
    else {
        is-deeply ($csv.csv (in => $in, headers => [@hdr], frag => "row=2-*"),
            $full-aoh, "csv => Hash + hdrs { s-in ($in) }");
        }
    }

my $aoa = [ $full-aoa.list[1,2] ];
is-deeply (csv (file => $fni, headers  => "skip"),    $aoa, "AOA skip");
is-deeply (csv (file => $fni, fragment => "row=2-3"), $aoa, "AOA fragment");

is-deeply (csv (in => $fni, encoding => "utf-8", headers => ["a", "b", "c"],
                fragment => "row=2", sep_char => ","),
       [{ :a("1"), :b("2"), :c("3") },], "AOH headers fragment");

ok (csv (in => $aoa, out => $fno), "AOA out file");
is-deeply (csv (in => $fno), $aoa, "AOA parse out");

ok (csv (in => $full-aoh, out => $fno, headers => "auto"), "AOH out file");
is-deeply (csv (in => $fno, headers => "auto"), $full-aoh, "AOH parse out");

ok (csv (in => $full-aoh, out => $fno, headers => "skip"), "AOH out file no header");
is-deeply (csv (in => $fno, headers => [ $full-aoh.list[0].keys ]),
    $full-aoh, "AOH parse out no header");

my int $idx = 0;
sub getrowa { return $full-aoa[$idx++]; }
sub getrowh { return $full-aoh[$idx++]; }

ok (csv (in => &getrowa, out => $fno), "out from CODE/AR");
is-deeply (csv (in => $fno), $full-aoa, "data from CODE/AR");

$idx = 0;
ok (csv (in => &getrowh, out => $fno, headers => [ @hdr ]), "out from CODE/HR");
is-deeply (csv (in => $fno, headers => "auto"), $full-aoh, "data from CODE/HR");

$idx = 0;
ok (csv (in => &getrowh, out => $fno), "out from CODE/HR (auto headers)");
is-deeply (csv (in => $fno, headers => "auto"), $full-aoh, "data from CODE/HR");

is (csv (in => [$[1,2,3]], out => Str), "1,2,3\r\n"|"1,2,3\n", "Out to Str");

ok (csv (in => $aoa.iterator, out => $fno), "AOA out file");
is-deeply (csv (in => $fno), $aoa, "AOA parse out");

done-testing;
