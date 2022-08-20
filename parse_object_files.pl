use Data::Dumper;
use IPC::Open2;
$nodenum=1;

my $database = {};
foreach(@ARGV) {
	open(my $in,"<",$_) or next;
	$database = loadFiles($database,$in);
}
$Data::Dumper::Sortkeys = 1;

analysis($database);
# analysis2 --- not yet

#print Dumper($database); exit 0;

my $main="main";
my $dotout = "digraph \"$main\" {\n";

load_tags($database);
load_sources($database);
$main=$database->{"#Functions"}{$main};
outCallChain( \$dotout,"main", $main );
#print Dumper($database); exit 0;
outNodes(\$dotout,"TOP",$database->{"#Files"});
$dotout .= "\n}\n";
print $dotout;


open(DB,">","care.db");
print DB Dumper($database);
close(DB);

exit 0;

sub loadFiles {
	my $database = shift;
	my $in=shift;
	my $currentFunction={};
	my $currentFile={};
	my $fun="???";
	my $file="???";

	sub fun { 
	    $fun = shift; 
	    $currentFunction = \$database->{"#Functions"}->{$fun};
	    $currentFile     = \$database->{"#Files"}->{$file};

	    push @{$$currentFunction->{"#File"}}, $file;
	    #push @{$database->{"#Files"}->{$file}->{"#Defined"}},$fun;
	    $database->{"#Files"}->{$file}->{"#Defined"}->{$fun}=-1;
	}
	sub refer {
	    my $fun = shift;
	    $$currentFunction->{$fun}++;
	    # Not used here, tags sets these 
	     $$currentFile->{"#Links"}->{$fun}++;


	}


	while (<$in>) {
	    chomp;
	    $file = $1 if /^(.*):\s+file\s+format/;
	    fun($1) if /^[0-9a-f]+\s<([^>]+)>/;
	    refer($1)  if /: R_[A-Z0-9_]+\s+([^\.]\S+?)(\+0x[0-9a-f]+)?$/;
	    refer($1)  if /:\s.* <(\S+)\@plt>/;
	}
	return $database;
}

sub analysis {
	my $database = shift;
	my $allfuns = $database->{"#Functions"};
	my $allfiles= $database->{"#Files"};
	foreach $fun ( keys %$allfuns ) {
		next if  $fun =~ /^#/;
		my $thisFunction  = $allfuns->{$fun};
		foreach ( keys %$thisFunction ) { 
			next if /^#/;
			my $calledFunction = $allfuns->{$_};
			next unless ref $thisFunction->{$_}  eq "";
			next unless defined( $allfuns->{$_} ); 
			$calledFunction->{"#CalledBy"}->{$_}++ if defined $calledFunction;
			my @calledFiles = @{$allfuns->{$_}->{"#File"}};
			foreach (@calledFiles) {
				$thisFunction->{"#CalledFrom"}->{$_}++;
			}
			foreach $file ( @{$thisFunction->{"#File"}}) {
				foreach $called ( @calledFiles ) {
					$allfiles->{$file}->{"#Calls"}->{$called}++;
				}
			}

		}
	}
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
    out(@_);
    # Fix DB info about used files
    while( my ($f,$cnt) = each %$files ) {
	    $database->{"#Files"}->{$f}->{"#Called"} += $cnt;
    }
    
    sub out {
	    my ( $name, $itm ) = @_;  # print("CK:$name\n");
	    return if $itm->{"#Done"}++;
	    foreach( @{$itm->{"#File"}}) {
		    $files->{$_}++;
	    }
	    while ( my ( $k, $v ) = each %$itm ) {
		next if $k =~ /^#/;
		next unless ref $v eq "REF";
		$$dotout .=  "\"$name\" -> \"$k\";\n";
		out( $k, $$v );
	    }
	}
}


sub outNodes {
    my $dotout = shift;
    my ( $name, $itm ) = @_;  # print("CK:$name\n");
    my $files = $itm;
    while ( my ( $k, $v ) = each %$files ) {
	    next unless $v->{"#Called"};
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
		    $$dotout .= "    $n [$url];\n";
	    }
	    #$$dotout .=  "   ".join(";\n   ", sort keys %{$v->{"#Defined"}} ).";\n";
	    $$dotout .=  "}\n";
	    $nodenum++;
    }
}

sub load_tags {
	my $database = shift;
	#Implicit tags file with line format
	open(TAGS,"<","tags") or return;

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

		foreach( @$file ) {
			next unless my $thisFile = $allFiles->{$_};
			$thisFile->{"#Source"} = $2;
			$thisFile->{"#Defined"}->{$1} = $3;
		}

		# $sym->{$2}->{$1} = $3;
		# $sym->{$2}->{objc} = $allFun->{$1}->{"#File"};
		# $fun->{"#Loc"}= { $2 => $3 };
	}
}


sub load_sources {
    my $database = shift;
    my $allFiles = $database->{"#Files"};
    my $mapfile;
    my $urls = {};
    while( my ($file, $v) = each %$allFiles ) {
	my $inFile = $v->{"#Source"};
	my $outFile = $inFile;
	$outFile =~ s|/|_|g;
	$outFile =~ s|^(\._)?||;
	$outFile .= ".html";
	$mapfile->{$file} = $outFile;
	$v->{"#HTML"} = $outFile;
    }
    my $htmls;
    while( my ($file, $v) = each %$allFiles ) {
	my $inFile = $v->{"#Source"};

	my @result = get_html($inFile);
       print STDERR "Read: $inFile\n";
       foreach $f ( keys %{$v->{"#Links"}} ) {
	   next unless my $fun = $database->{"#Functions"}->{$f};
	   my $definedIn = $fun->{"#File"}[0];
	   my $ref = $mapfile->{$definedIn} . "#cb1-" . $allFiles->{$definedIn}->{"#Defined"}->{$f};
	   $urls->{$f} = $ref;
	   grep {s|(<span id.*)(\b\Q$f\E\b)|$1<a href="$ref">$2</a>|} @result;
       }
       $htmls->{$v->{"#HTML"}} = \@result;
    }
    $database->{"#URLS"}=$urls;
    #Dump outfiles...
	$DB::single=1;
    while ( my ($fn,$content) = each %$htmls ) {
	print STDERR "Writing: $html/$fn\n";
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
