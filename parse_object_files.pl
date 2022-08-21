#!/usr/local/bin/perl -w
use Data::Dumper;
use IPC::Open2;

# Small tool to help analysing object files ( preferably *.o understood by objdump )
# This will create annotated source-html and a graphviz file showing the call graphs
#
#
# Read and parse and create dot file and related hrefs html using pandoc
# Usage:
# perl  parse_object_files.pl $(cat cont.list) -savedb files_loaded.db tags analysis -savedb analysed.db html new.dot && dot   -Tsvg new.dot -o html/out.svg
#
# or 
# perl parse_object_files.pl analysed.db html new.dot && dot   -Tsvg new.dot -o html/out.svg
# Inputs accepted:
#     *.o  : object files to be parsed by objdump
#     *.db : perl-database containing all current state (to restore state)
#     *.log : output from some objdump command ( -t -d -r, seems good.... )
#     -savedb *.db :  Save database state into file
#     analysis :  post process loaded objects and link relations (optional)
#     tags : load source references also from tags file
#            (future:  use '-g' from object format to find source locations )
#     html : use pandoc to create annotated html sources (stored in ./html/* )
#     *.dot : Create dot format of understood content  (url references to html files
#     	      If the name matches function-XXXX.dot the function XXXX will be used as root instead of "main"
#
#  parsing of dot files:  dot   -Tsvg new.dot -o html/out.svg
#
#

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Purity = 1;
use lib ".";
$nodenum=1;

my $database = {};
while (@ARGV) {
	$_ = shift @ARGV;
	if (/\.db$/ ) {
		load_db($_);
	} elsif (/\.o$/) {
		load_elf($_,$database);
	} elsif (/\.log$/) {
		load_log($_);
	} elsif (/^analysis/) {
		analysis($database);
	} elsif (/^html$/) {
		load_sources($database);
	} elsif (/tags$/ && -r $_) {
		load_tags($_,$database);
	} elsif (/\.dot$/) {
	    	analysis($database) unless $database->{"#Analysed"};
		save_dot($_);
	} elsif (/^-savedb$/) {
		save_db(shift @ARGV);
	} else {
		die "Filename bad: $_";
	}
}


exit 0;
# analysis2 --- not yet

#print Dumper($database); exit 0;

sub save_dot {
	my $dotfile=shift;

	my $main="main";
	$main = $1 if $dotfile =~ /^function[_\-](.*)\.dot$/;
	my $dotout = "digraph \"$main\" {\n";

	# load_sources($database);
	my $mainf=$database->{"#Functions"}{$main};
	outCallChain( \$dotout,$main, $mainf );
	#print Dumper($database); exit 0;
	outNodes(\$dotout,"TOP",$database->{"#Files"});
	$dotout .= "\n}\n";
	open(DOT,">",$dotfile);
	print DOT $dotout;
	close(DOT);
	print STDERR "Dot: $dotfile written\n";
}


sub save_db {
	my $save_db = shift;
	open(DB,">",$save_db);
	print DB Dumper($database);
	close(DB);
	print STDERR "Database saved: $save_db\n";
}


sub parseDmp {
	my $dmp=shift;
	my $database = shift;

	my $currentFunction={};
	my $currentFile={};
	my $fun="???";
	my $file="???";

	my $recordFile = sub {
		$file = shift;
		$file =~ s/\@plt//;
	    	$currentFile     = \$database->{"#Files"}->{$file};

	};
	my $recordFun = sub { 
	    $fun = shift; 
	    $fun =~ s/(\@plt)?([+-]0x[0-9a-f]*)?$//;
	    $currentFunction = \$database->{"#Functions"}->{$fun};
	    push @{$$currentFunction->{"#File"}}, $file;

	    $$currentFile->{"#Defined"}->{$fun}=-1;
	};
	my $recordRefer = sub {
	    my $fun = shift;
	    $fun =~ s/(\@plt)?([+-]0x[0-9a-f]*)?$//;
	    $$currentFunction->{"#Calls"}->{$fun}++;
	    # Not used here, tags sets these 
	     $$currentFile->{"#Links"}->{$fun}++;


	};
	# 2085ab:       e9 c0 fb ff ff          jmpq   208170 <atexit@plt-0x10>
	# 00000000002085b0 <kill@plt>:

	foreach( @$dmp) {
	    chomp;
	    &$recordFile($1) if /^(.*):\s+file\s+format/;
	    $$currentFile->{"#SomeSource"} = $1 if /\sdf\s+\*ABS\*\s+0+\s(.*\.c)$/;
	    &$recordFun($1) if /^[0-9a-f]+\s<([^>]+)>/;
	    &$recordRefer($1)  if /: R_[A-Z0-9_]+\s+([^\.]\S+?)(\+0x[0-9a-f]+)?$/;
	    &$recordRefer($1)  if /:\s.* <(\S+)?>/;
	}
	return $database;
}
sub analysis {
	my $database = shift;
	my $allfuns = $database->{"#Functions"};
	my $allfiles= $database->{"#Files"};

	# Link functions together
	foreach $fname ( keys %$allfuns ) {
		my $thisFunction = $allfuns->{$fname};
		my $calling = $thisFunction->{"#Calls"};
		next unless $calling;
		# print STDERR "Fix: $fname\n";

		foreach ( keys %$calling ){
			next if ref $calling->{$_};
			my $calledFunction = \$allfuns->{$_};
			next unless ref $$calledFunction;  
			# print STDERR " -> $_\n";

			$$calledFunction->{"#CalledBy"}->{$fname}++;
			$calling->{$_} = $calledFunction;
		}
	}
	#die Dumper($allfuns);
	$database->{"#Analysed"} = "yes";
	return;

	## Maybe link file sections too ?
}



sub analysis2 {
	my $database = shift;
	print STDERR "Analysis per file\n";

	my $main="main";
	my $allFuns = $database->{"#Functions"};
	my $allFiles= $database->{"#Files"};
	foreach (keys %{$allFuns->{$main}}) {
			next if /^#/;
			#$database->{"# Tree"}->{$main}->{$_} = $database->{
			#}
		}
	my @files= @{$allFuns->{$main}->{"#File"}};
	foreach ( @files ) {
		last;
		my @calls = @{$allFiles->{$_}->{"#Calls"}};
		foreach ( @calls ) {
			$database->{"# Tree"}->{$main}->{$_}=1;
		}
	}
}



sub outCallChain {
    my $dotout = shift;
    my $files;
    *dotOut = sub {
	my ( $name, $itm ) = @_;  print("CK:$name\n");
	    return if $itm->{"#Done"}++;
	    foreach( @{$itm->{"#File"}}) {
		    $files->{$_}++;
	    }
	    my $calls = $itm->{"#Calls"};
	    while ( my ( $k, $v ) = each %$calls ) {
		next if $k =~ /^#/;
		next unless ref $v eq "REF";
		$$dotout .=  "\"$name\" -> \"$k\";\n";
		dotOut( $k, $$v );
	    }
	};
    dotOut(@_);
    # Fix DB info about used files
    while( my ($f,$cnt) = each %$files ) {
	    $database->{"#Files"}->{$f}->{"#Called"} += $cnt;
    }
    
}


sub outNodes {
    my $dotout = shift;
    my ( $name, $itm ) = @_;  
    my $files = $itm;
    while ( my ( $k, $v ) = each %$files ) {
	    next unless $v->{"#Called"};
	    print("CK Node:$k\n");
	$DB::single=1;
	    my $f = $k; 
	    $f =~ s,^.*/,,;
	    $$dotout .=  <<EOM;
	    rankdir="LR";
	    subgraph cluster_$nodenum {
	    rankdir="TB";
	    style=filled;
	    color=lightgrey;
	    node [style=filled,color=white];
	    label = "$f";
EOM
	    foreach $n ( sort keys  %{$v->{"#Defined"}} ) {
		    my $url = "";
		    my $u = $database->{"#URLS"}->{$n};
		    $url = "URL=\"$u\"" if $u;
		    $$dotout .= "    \"$n\" [$url];\n";
	    }
	    #$$dotout .=  "   ".join(";\n   ", sort keys %{$v->{"#Defined"}} ).";\n";
	    $$dotout .=  "}\n";
	    $nodenum++;
    }
}

sub load_tags {
	my $tag = shift;
	my $database = shift;
	open(TAGS,"<",$tag) or return;

	my $sym={};
	my $allFun = $database->{"#Functions"};
	my $allFiles= $database->{"#Files"};
	die "No database..." unless $allFiles;
	while(<TAGS>) {
		# Format depends on exctags --fields=n
		next unless /^(\S+)\s+(\S+).*line:(\d+)/;
		next unless -r $2;
		next unless my $fun = $allFun->{$1};
		next unless my $file= $fun->{"#File"};
		my ($t,$f,$l) = ( $1,$2,$3);

		foreach( @$file ) {
			next unless my $thisFile = $allFiles->{$_};
			my $m=$thisFile->{"#SomeSource"} ;
			next if $m && ! ($f =~ m|/$m$|);
			$thisFile->{"#Defined"}->{$t} = $l;
			$thisFile->{"#Source"} = $f;
		}

		# $sym->{$2}->{$1} = $3;
		# $sym->{$2}->{objc} = $allFun->{$1}->{"#File"};
		# $fun->{"#Loc"}= { $2 => $3 };
	}
	$database->{"#Tags"} = $tag;
}


sub load_sources {
    my $database = shift;
    my $allFiles = $database->{"#Files"};
    my $mapfile;
    my $urls = {};
    while( my ($file, $v) = each %$allFiles ) {
	my $inFile = $v->{"#Source"};
	my $outFile = $inFile;
	# die Dumper($database) . "Ups? $file".Dumper($v)  unless $inFile;
	next unless $inFile;
	$outFile =~ s|/|_|g;
	$outFile =~ s|^(\._)?||;
	$outFile .= ".html";
	$mapfile->{$file} = $outFile;
	$v->{"#HTML"} = $outFile;
    }
    my $htmls;
    *patch_source = sub {
	    my ($file,$v) = @_;
		my $inFile = $v->{"#Source"};
		warn "no: inFile $file" unless defined $inFile;
		die "Double? Source:$inFile $file HTML:".$v->{"#HTML"} if $htmls->{$v->{"#HTML"}};
		my @result = get_html($inFile);
	       print STDERR "Read: $inFile  ($file) ($v->{'#HTML'})\n";
	       foreach $f ( keys %{$v->{"#Links"}},keys %{$v->{"#Defined"}} ) {
		   next unless my $fun = $database->{"#Functions"}->{$f};
		   my $definedIn = $fun->{"#File"}[0];
		   my $ref = $mapfile->{$definedIn} . "#cb1-" . $allFiles->{$definedIn}->{"#Defined"}->{$f};
		   $urls->{$f} = $ref;
		   grep {s|(<span id.*)(\b\Q$f\E\b)|$1<a href="$ref">$2</a>|} @result;
	       }
	       $htmls->{$v->{"#HTML"}} = \@result;
       };
    while( my ($file, $v) = each %$allFiles ) {
	patch_source($file,$v) if $v->{"#Source"};
    }
    print STDERR "URL: ".Dumper($database->{"#URLS"});
    $database->{"#URLS"}=$urls;
    print STDERR "URL: -> ".Dumper($database->{"#URLS"});
    #Dump outfiles...
    while ( my ($fn,$content) = each %$htmls ) {
	print STDERR "Writing: html/$fn\n";
	open(my $of,">","html/$fn");
	print $of @$content;
	close $of;
    }
}





sub get_html {
    my $inFile = shift;
    my $js= "--variable=include-before:".get_javascript();
    my $pid = open2(my $chld_out, my $chld_in, qw{/usr/local/bin/pandoc -s --metadata},"title=$inFile",$js,"--variable=linkcolor:#263e9a;font-style: italic;");
    #my $pid = open2(my $chld_out, my $chld_in, qw{tee file.md});
    print $chld_in  "```{.c .numberLines}\n";
    open(my $f,"<",$inFile);
    my @l = <$f>;
    close($f);
    print $chld_in @l;
    print $chld_in "```\n";
    close($chld_in);
    my @result = <$chld_out>;
    close($chld_out);

    # reap zombie and retrieve exit status
    waitpid( $pid, 0 );
    my $child_exit_status = $? >> 8;
    return @result;
}

sub get_javascript {
return  <<EOM;
<style>
 .TopLoc {position: fixed;top: 10px;right: 10px;}
</style>

<script>

function doit(hide) {
	if (hide) {
		document.querySelectorAll('.co').forEach(function (a) {a.style.visibility=""})

	} else {
		document.querySelectorAll('.co').forEach(function (a) {a.style.visibility="hidden"})
	}
}
</script>

<div class="TopLoc"> 
<button type="button" onclick="doit(true) ">Show Comments</button>
<button type="button" onclick="doit(false) ">Hide Comments</button>
</div>
EOM

}
sub load_log {
	my $f = shift;
	open(my $in,"<",$f) or next;
	my @dmp = <$in>;
	close $in;
	$database = parseDmp(\@dmp,$database);
	# $database = loadFiles($database,$in);
}
sub load_db {
	my $f = shift;
	return unless -r $f;
	$::VAR1={};
	eval { do $f; };
	my $db=$::VAR1;
	my %ndb = ( %$database, %$db );
	$database = \%ndb;
}

sub load_elf {
	my $f = shift;
	my $database = shift;
	delete $database->{"#Tags"};
	delete $database->{"#Analysed"};
	my @cmd = qw{objdump -t  -d -r};
	open(my $dmp,"-|",@cmd,$f) or die "$?";
	my @res = <$dmp>;
	close($dmp);
	$database = parseDmp(\@res,$database);

	#die Dumper($database);
	#die "nope $f";
}
