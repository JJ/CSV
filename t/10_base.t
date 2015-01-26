#!perl6

use v6;
use Slang::Tuxic;

use Test;
use Text::CSV;

my $csv = Text::CSV.new;

# For now only port the PASSing tests, no checks for FAIL (die vs return False)

ok ($csv,                                      "New parser");
is ($csv.fields, Nil,                          "fields () before parse ()");
is ($csv.string, Nil,                          "string () undef before combine");
is ($csv.status, True,                         "No failures yet");

ok (1, "combine () & string () tests");
is ($csv.combine (),    True,                  "Combine no args");
is ($csv.string,        "",                    "Empty string");

# binary is now true by default.
# create rejection of \n with binary off later
ok ($csv.combine (""),                         "Empty string - combine ()");
is ($csv.string, "",                           "Empty string - string ()");
ok ($csv.combine ("", " "),                    "Two fields, one space - combine ()");
is ($csv.string, '," "',                       "Two fields, one space - string ()");
ok ($csv.combine ("", 'I said, "Hi!"', ""),    "Hi! - combine ()");
is ($csv.string, ',"I said, ""Hi!""",',        "Hi! - string ()");
ok ($csv.combine ('"', "abc"),                 "abc - combine ()");
is ($csv.string, '"""",abc',                   "abc - string ()");
ok ($csv.combine (","),                        "comma - combine ()");
is ($csv.string, '","',                        "comma - string ()");
ok ($csv.combine ("abc", '"'),                 "abc + \" - combine ()");
is ($csv.string, 'abc,""""',                   "abc + \" - string ()");
ok ($csv.combine ("abc", "def", "ghi", "j,k"), "abc .. j,k - combine ()");
is ($csv.string, 'abc,def,ghi,"j,k"',          "abc .. j,k - string ()");
ok ($csv.combine ("abc\tdef", "ghi"),          "abc + TAB - combine ()");
is ($csv.string, qq{"abc\tdef",ghi},           "abc + TAB - string ()");
is ($csv.status, True,                         "No failures");

$csv.binary = False;
is ($csv.combine ("abc", "def\n", "ghi"), False, "Bad character");
is ($csv.error_input, "def\n",                  "Error_input ()");
$csv.binary = True;

ok (1,                                         "parse () tests");
ok ($csv.parse ("\n"),                         "Single newline");
ok ($csv.parse ('","'),                        "comma - parse ()");
is ($csv.fields.elems, 1,                      "comma - fields () - count");
is ($csv.fields[0].text, ",",                  "comma - fields () - content");

ok ($csv.parse (qq{"","I said,\t""Hi!""",""}), "Hi! - parse ()");
is ($csv.fields.elems, 3,                      "Hi! - fields () - count");

is ($csv.fields[0].text, "",                   "Hi! - fields () - field 1");
is ($csv.fields[1].text, qq{I said,\t"Hi!"},   "Hi! - fields () - field 2");
is ($csv.fields[2].text, "",                   "Hi! - fields () - field 3");
is ($csv.status, True,                         "status");

ok ($csv.parse (""),                           "Empty line");
is ($csv.fields.elems, 1,                      "Empty - count");
is ($csv.fields[0].text, "",                   "One empty field");

ok (1,                                         "Integers and Reals");
ok ($csv.combine ("", 2, 3.25, "a", "a b"),    "Mixed - combine ()");
is ($csv.string, ',2,3.25,a,"a b"',            "Mixed - string ()");

ok (!$csv.parse ('"abc'),                      "Missing closing \"");
ok (!$csv.parse ('ab"c'),                      "\" outside of \"'s");
ok (!$csv.parse ('"ab"c"'),                    "Bad character sequence");
is ($csv.status, False,                        "Failure");

=finish

stuf not tested yet ...

ok (!$csv->parse (),                           "Missing arguments");
ok (!$csv->parse (qq("abc\nc")),               "Bad character (NL)");

# New from object
ok ($csv->new (),                              "\$csv->new ()");

my $state;
for ( [ 0, 0 ],
      [ 0, "foo" ],
      [ 0, {} ],
      [ 0, \0 ],
      [ 0, *STDOUT ],
      ) {
    eval { $state = $csv->print (@$_) };
    ok (!$state, "print needs (IO, ARRAY_REF)");
    ok ($@ =~ m/^Expected fields to be an array ref/, "Error msg");
    }