egrep '^=head2 ' r2/pod/Advanced/Thin.pod |
   egrep ' C<< ' |
   perl -n -E '
     s/.*[:][:]([CGRBOTV])->new[(][)].*/marpa_\L$1\l_new/ and print;
     s/.*[\$]([cgrbotv])->([^\(]*).*/marpa_$1_$2/ and print;
   ' > nogit/documented_method.list
perl -n -E '
    m/::CLASS_LETTER.*['"'"']([cgrbotv])['"'"'][;]/ and $class = $1;
    m/[\(]qw[\(](_[^ \)]*)[ \)]/ and say $1;
    m/[\(]qw[\(]([^_][^ \)]*)[ \)]/ and say "marpa_$class" . "_$1";
     ' r2/xs/gp_generate.pl > nogit/gp_method.list
perl -n -E '
  s/{[^}]*}/{}/g;
  m/^[@]deftypefn [^ ]+ [^ ]+ ([^ ]+) / and say $1;
  m/^[@]deftypefunx? [^ ]+ ([^ ]+) / and say $1;
' r2/libmarpa/dev/api.texi | sort > nogit/libmarpa_method.list
sort -u nogit/documented_method.list nogit/gp_method.list | comm -3 nogit/libmarpa_method.list -
